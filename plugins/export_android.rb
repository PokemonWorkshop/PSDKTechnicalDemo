# Export a PSDK project as an Android APK, or as a standalone .epsa / .psa
# archive. The extension of --output picks what is built:
#
#   .apk   Full APK (the default, as <name>.apk):
#            ruby export_android.rb [<name>] --apk PSDK-base.apk [options]
#          Builds, signs, and outputs a complete .apk from the base PSDK APK
#          template. The game archive is bundled inside, encrypted with a key
#          derived from the keystore's signing certificate (or plain with
#          --archive psa).
#
#   .epsa  Encrypted archive only:
#            ruby export_android.rb --apk  player.apk -o mygame.epsa
#            ruby export_android.rb --cert player.crt -o mygame.epsa
#          No apktool, no apksigner. The cert is the *public* X.509 cert of
#          the eventual APK that will play this archive — no private key
#          needed, no keystore needed. Either:
#            --apk <path-to-apk>  : extract the cert directly from the player
#                                   APK (the easy path — Pokemon Studio already
#                                   has the player APK for distribution).
#            --cert <path-to-cert>: hand the cert as a separate PEM/DER file.
#          Intended for makers who don't have direct access to the signing
#          keystore (for example, when the player APK is built by a CI server).
#
#   .psa   Plain archive only (an unencrypted ZIP, anyone can unzip it):
#            ruby export_android.rb -o mygame.psa
#
# <name> is the app name, project.studio's title by default. Run with --help
# for every option.
#
# Requirements:
#   - gem: rubyzip
#   - APK only: apktool (https://apktool.org), zipalign and apksigner
#     (Android SDK build-tools)
#
# Keystore note: APK mode reads the signing certificate via Ruby's OpenSSL
# (PKCS12 only) and binds the .epsa encryption key to it via HKDF. JKS or BKS
# keystores are not supported — convert them once to PKCS12 outside this
# pipeline. Archive mode bypasses this entirely; it just reads a public cert.
#
# Calling from Pokemon Studio:
#
#   Run this file directly with PSDK's bundled Ruby, cwd = the project root:
#     <PSDK ruby> <path>/export_android.rb [options]
#   NOT through `Game.rb --util=export_android`: PSDK leaves --util=... in
#   ARGV (rejected by the option parser), boots the whole script stack first,
#   and Studio's --disable=gems hides rubyzip. Drop --disable=gems here, or
#   bundle rubyzip with the PSDK binaries. On Linux / macOS the game-*.sh
#   wrappers always run Game.rb: use one that sources ruby-dist/setup.sh, then
#   runs `ruby "$@"`. The file only needs its require_relative siblings
#   (epsa_*.rb, pkcs12_cert.rb, apk_signing_block.rb) next to it, so it can
#   ship with Studio / the PSDK binaries rather than in each project.
#
#   Archive export (main path, no Java / Android SDK needed):
#     -o <out>/<Title>.epsa --apk <player.apk> [--compiled] [--with-saves]
#   --apk is the player APK Studio distributes: its signing cert keys the
#   archive. --compiled packs the output of Studio's compilation, run first;
#   its bytecode only plays on the PSDK-android app for the same Ruby (3.0
#   for Windows Studio), so pick the matching player APK. -o <Title>.psa
#   without --apk gives an unencrypted archive, for testing.
#
#   Full APK export (needs apktool, zipalign and apksigner on PATH: check
#   for them and disable the option otherwise):
#     -o <out>/<Title>.apk --apk <PSDK-base.apk> -k <project keystore dir>
#       [--package <id>] [--icon <png>] [--debug-mode] [--archive psa]
#   -k: a project-relative directory, so the generated debug.p12 travels with
#   the project (it holds a private key: keep it out of public repositories).
#   Pass the keystore password as PSDK_KS_PASS in the child's environment,
#   not with --ks-pass.
#
#   No <name>: Studio's compilation already writes the title into
#   project.studio. --keep-tmp and --no-mega-script are for debugging and
#   legacy APKs only.
#
#   Output: exit code 0 on success; 1 with the error on stderr otherwise.
#   stdout reports progress as `[n/total] ...` step lines (6 steps for an
#   APK, 1 for an archive) and ends with `Output: <path> (<n> bytes)`.
#   Warnings (ignored options, small or non-PNG icon) go to stderr.

require 'zip'
require 'json'
require 'zlib'
require 'openssl'
require 'optparse'
require 'tmpdir'
require 'fileutils'

require_relative 'epsa_format'
require_relative 'epsa_kdf'
require_relative 'epsa_writer'
require_relative 'pkcs12_cert'

# ---------------------------------------------------------------------------
# mega_script.deflate generation
# ---------------------------------------------------------------------------
#
# Marshal+Deflate bundle of every Ruby source PSDK would normally load on
# boot, keyed by project-relative path. ScriptLoad.rb#unpack_scripts inflates
# this on the first run, writes each entry back to disk verbatim, and the
# normal `require` chain reads them at native speed afterwards.
#
# Bundle bytes are PORTABLE across platforms / Ruby ABIs — we store source
# strings, not iseq binaries. (Iseq binaries from `RubyVM::InstructionSequence
# #to_binary` are NOT portable, which is why PSDK's own `pack_scripts` mode
# can't be used cross-platform.)
#
# On Android specifically, the .epsa is AES-encrypted and every PhysFS read
# goes through an EpsaStream decrypt callback. Without this bundle, booting
# PSDK means ~hundreds of small encrypted reads (one per .rb) — ~30s wall
# clock. With this bundle: one big PhysFS read of the deflate, one Marshal-
# load, then every subsequent require hits the native filesystem.
#
# Returns the deflate bytes; nothing is written into the project. A
# mega_script.deflate left in pokemonsdk/scripts/ is unpacked by
# ScriptLoader.start on the next desktop launch, overwriting every project
# script with its export-time version (edits made since are lost).
MEGA_SCRIPT_ARCHIVE_PATH = 'pokemonsdk/scripts/mega_script.deflate'.freeze

def build_mega_script_deflate
  index_path      = 'pokemonsdk/scripts/script_index.txt'
  project_dir     = 'scripts'
  file_pattern    = /\A[0-9]{3,5}[ _].*\.rb\z/
  folder_pattern  = /\A[0-9]+[ _][^\/]+\z/

  abort "  Cannot build mega_script.deflate: missing #{index_path}\n" \
        "  (run this script from a PSDK project root)" unless File.exist?(index_path)

  bundle = {}

  # PSDK scripts: the script_index is authoritative — that's exactly the
  # set ScriptLoader#load_script_from_index will `require`.
  psdk_paths = File.readlines(index_path, chomp: true).reject(&:empty?)
  psdk_paths.each do |rel|
    if File.file?(rel)
      bundle[rel] = File.binread(rel)
    else
      warn "  skip: #{rel} (in #{index_path} but missing on disk)"
    end
  end
  # Include the index itself so post-unpack reads of it stay native.
  bundle[index_path] = File.binread(index_path)

  # Project scripts: mirror ScriptLoader#load_vscode_scripts — root .rb files
  # first (alphabetical), then recurse into numerically-named subdirectories
  # (alphabetical). The Hash iteration order doesn't matter for correctness
  # (unpack_scripts just writes), but the deterministic walk keeps the output
  # bytewise stable when nothing's changed.
  walk = lambda do |dir|
    return unless Dir.exist?(dir)
    entries = Dir.children(dir).sort
    entries.each do |name|
      full = File.join(dir, name)
      bundle[full] = File.binread(full) if File.file?(full) && name.match?(file_pattern)
    end
    entries.each do |name|
      full = File.join(dir, name)
      walk.call(full) if File.directory?(full) && name.match?(folder_pattern)
    end
  end
  walk.call(project_dir)

  [Zlib::Deflate.deflate(Marshal.dump(bundle)), bundle.size]
end

# ---------------------------------------------------------------------------
# Project icon
# ---------------------------------------------------------------------------

RELEASE_DIR = 'Release'
PNG_SIGNATURE = "\x89PNG\r\n\x1A\n".b

# The game's own icon in a compiled release: graphics/icons/game.png (the
# window icon), packed by the compiler under the 'game' key of the Yuki::VD
# archive Release/graphics/icon. A Yuki::VD starts with the 4-byte offset of
# a Marshal'd { name => offset } index; each entry is a 4-byte size + data.
def compiled_game_icon(release_dir)
  File.open(File.join(release_dir, 'graphics', 'icon'), 'rb') do |f|
    f.pos = f.read(4).unpack1('L<')
    offset = Marshal.load(f)['game'] or return nil
    f.pos = offset
    data = f.read(f.read(4).unpack1('L<'))
    data if data&.start_with?(PNG_SIGNATURE)
  end
rescue StandardError
  nil
end

# The project icon, as [path, source] (nil when there is none). --compiled:
# the release's own game icon, extracted into work_dir, so that packing a
# release compiled from another project doesn't pick up this directory's
# project.studio (which isn't part of a release). Otherwise: the icon as
# Studio knows it, project.studio's iconPath, e.g. a 154x154 PNG at the
# project root.
def project_icon(compiled_mode, studio, work_dir)
  if compiled_mode
    icon_data = compiled_game_icon(RELEASE_DIR) or return nil
    path = File.join(work_dir, 'game_icon.png')
    File.binwrite(path, icon_data)
    [path, "#{RELEASE_DIR}/graphics/icon"]
  else
    icon = studio['iconPath']
    [icon, 'project.studio'] if icon.is_a?(String) && !icon.empty? && File.file?(icon)
  end
end

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

opts = {}
parser = OptionParser.new do |o|
  o.require_exact = true
  o.banner = 'Usage: ruby export_android.rb [<name>] [options]'
  o.separator ''
  o.separator '<name> is the app name (default: project.studio title). The --output extension'
  o.separator 'picks what is built: .apk (full APK), .epsa (encrypted archive only) or .psa'
  o.separator '(plain archive only).'
  o.separator ''
  o.on('-o', '--output PATH', 'Output .apk, .epsa or .psa (default: <name>.apk)') { |v| opts[:output] = v }
  o.on('--apk PATH', 'APK: the base PSDK APK template.',
       '.epsa: the player APK, whose signing cert keys the archive') { |v| opts[:apk] = v }
  o.on('--cert PATH', ".epsa: the player APK's public signing cert (PEM/DER), instead of --apk") { |v| opts[:cert] = v }
  o.on('--compiled', 'Pack the desktop compile output (Release/, from Studio\'s "compile"',
       'or `game --util=project_compilation`) instead of the project sources:',
       'the app installs it without compiling on the device. Its bytecode only',
       'runs on the PSDK-android variant of the Ruby that compiled it',
       '(printed below; Windows Studio: ruby3.0).') { opts[:compiled] = true }
  o.on('--with-saves', 'Include the Saves folder in the archive') { opts[:with_saves] = true }
  # --no-mega-script: don't bundle mega_script.deflate. For APKs built on the
  # older v0.7.0 engine, whose ScriptLoad.rb doesn't expect it.
  o.on('--no-mega-script', "Don't bundle #{MEGA_SCRIPT_ARCHIVE_PATH}",
       '(APKs based on the older v0.7.0 engine)') { opts[:no_mega_script] = true }
  o.on('--keep-tmp', 'Keep temporary files for debugging') { opts[:keep_tmp] = true }
  o.separator ''
  o.separator 'APK only:'
  o.on('--archive TYPE', %w[epsa psa], 'Archive bundled in the APK: epsa (encrypted, default)',
       'or psa (plain ZIP, anyone can unzip it)') { |v| opts[:archive] = v }
  o.on('--icon PATH', 'App icon (PNG, recommended 192x192). Default: the project icon',
       "from project.studio (iconPath) when it is a PNG (with --compiled: the",
       "release's own graphics/icons/game.png, from Release/graphics/icon),",
       "else the base APK's icon") { |v| opts[:icon] = v }
  o.on('--package ID', 'Package ID (default: com.psdk.<name, alphanumerics only>)') { |v| opts[:package] = v }
  o.on('-k', '--keystore PATH', 'PKCS12 keystore, or a directory holding (or to hold) an',
       'auto-generated debug.p12. Default: ~/.psdk/. Pokemon Studio sets this to',
       'a project-relative directory so the keystore travels with the project') { |v| opts[:keystore] = v }
  o.on('--ks-pass PASSWORD', 'Keystore password (default: $PSDK_KS_PASS, else "android")') { |v| opts[:ks_pass] = v }
  # --debug-mode: produce an APK that launches the game in DEBUG_UNCOMPILED
  # instead of RELEASE. The Android side reads the manifest meta-data tag
  # we inject below (com.psdk.CLASSIC_DEFAULT_MODE) and routes the launch
  # through start.rb's PhysFS-mount path: Game.rb is read straight out of
  # the bundled .epsa, no compile step. Useful for QA / dev distribution
  # where you want a working APK without paying the compile latency on
  # first launch.
  o.on('--debug-mode', 'Debug-launch APK: Game.rb runs straight out of the bundled',
       'archive via PhysFS, skipping the on-device compile step') { opts[:debug_mode] = true }
  o.on('-h', '--help', 'Show this help') do
    puts o
    exit
  end
end

begin
  parser.parse!
rescue OptionParser::ParseError => e
  abort "#{e.message}\n\n#{parser}"
end
abort "Unexpected arguments: #{ARGV.drop(1).join(' ')}\n\n#{parser}" if ARGV.size > 1

compiled_mode = opts[:compiled]
debug_mode    = opts[:debug_mode]
keep_tmp      = opts[:keep_tmp]

studio = begin
  JSON.parse(File.read('project.studio'))
rescue StandardError
  nil
end
studio = {} unless studio.is_a?(Hash)

app_name = ARGV.first
app_name ||= studio['title'] if studio['title'].is_a?(String) && !studio['title'].strip.empty?
no_name_message = 'Missing <name>: project.studio has no title to default to'

output_path = opts[:output]
unless output_path
  abort no_name_message unless app_name
  output_path = "#{app_name.gsub(/\s+/, '_')}.apk"
end
output_kind = File.extname(output_path).downcase.delete_prefix('.')
abort "--output must end in .apk, .epsa or .psa: #{output_path}" unless %w[apk epsa psa].include?(output_kind)
apk_mode = output_kind == 'apk'

# ---------------------------------------------------------------------------
# Validation
# ---------------------------------------------------------------------------
#
# Only contradictions abort: options that don't apply to the mode are
# ignored with a warning.

abort '--compiled is incompatible with --debug-mode (a compiled release has no sources to run)' \
  if compiled_mode && debug_mode
abort '--compiled: missing Release/Game.yarb (compile the project first)' \
  if compiled_mode && !File.file?('Release/Game.yarb')
abort 'Missing Game.rb: launch the project once from Pokemon Studio (it writes Game.rb), or export with --compiled' \
  if !compiled_mode && !File.file?('Game.rb')

if apk_mode
  plain_mode = opts[:archive] == 'psa'
  base_apk_path = opts[:apk]
  abort 'Missing --apk <path>: path to the base PSDK APK template' unless base_apk_path
  abort "Base APK not found: #{base_apk_path}" unless File.exist?(base_apk_path)
  abort "Icon not found: #{opts[:icon]}" if opts[:icon] && !File.exist?(opts[:icon])
  abort no_name_message unless app_name
  safe_name = app_name.downcase.gsub(/[^a-z0-9]/, '')
  abort 'App name must contain at least one letter or digit' if safe_name.empty?
  warn '  --cert ignored: an APK is encrypted for the cert of the keystore that signs it' if opts[:cert]
else
  plain_mode = output_kind == 'psa'
  ignored = %i[archive icon package keystore ks_pass debug_mode].select { |key| opts[key] }
  warn "  Ignored without an APK to build: #{ignored.map { |key| "--#{key.to_s.tr('_', '-')}" }.join(', ')}" \
    unless ignored.empty?
  if plain_mode
    warn '  --apk / --cert ignored: a .psa archive is not encrypted' if opts[:apk] || opts[:cert]
  else
    cert_path = opts[:cert]
    base_apk_path = opts[:apk]
    abort "A .epsa archive is encrypted for its player APK: pass --apk <player.apk> or --cert <cert.pem>" \
      unless cert_path || base_apk_path
    abort 'Pass either --apk or --cert, not both' if cert_path && base_apk_path
    abort "Cert file not found: #{cert_path}" if cert_path && !File.exist?(cert_path)
    abort "APK file not found: #{base_apk_path}" if base_apk_path && !File.exist?(base_apk_path)
  end
end

# ---------------------------------------------------------------------------
# Tool checks
# ---------------------------------------------------------------------------

def check_tool(name)
  found = if Gem.win_platform?
    system("where #{name} > NUL 2>&1")
  else
    system("which #{name} > /dev/null 2>&1")
  end
  abort "Required tool not found: #{name}\nPlease install it and ensure it's in your PATH." unless found
end

if apk_mode
  check_tool('apktool')
  check_tool('zipalign')
  check_tool('apksigner')
end

# ---------------------------------------------------------------------------
# Derived values
# ---------------------------------------------------------------------------

# Every temporary file goes here, removed on exit (aborts included).
work_dir = Dir.mktmpdir('psdk_export_android')
at_exit do
  if keep_tmp
    puts "  Temporary files kept in #{work_dir}"
  else
    FileUtils.rm_rf(work_dir)
  end
end

studio_icon_path, studio_icon_source = project_icon(compiled_mode, studio, work_dir)

if apk_mode
  package_id    = opts[:package] || "com.psdk.#{safe_name}"
  keystore_pass = opts[:ks_pass] || ENV['PSDK_KS_PASS'] || 'android'
  icon_path     = opts[:icon]
  icon_source   = nil
  # No --icon: the project's icon. It replaces the base APK's logo.png, so
  # it must be a PNG (aapt2 refuses anything else when rebuilding).
  if !icon_path && studio_icon_path
    if File.binread(studio_icon_path, 8) == PNG_SIGNATURE
      icon_path = studio_icon_path
      icon_source = studio_icon_source
      # PNG IHDR: width and height, big-endian, right after the signature.
      width, height = File.binread(studio_icon_path, 8, 16).unpack('NN')
      warn "  #{studio_icon_source} icon is only #{width}x#{height}: it will look blurry on the launcher (use --icon)" \
        if [width, height].min < 96
    else
      warn "  #{studio_icon_source} icon #{studio_icon_path} is not a PNG: keeping the base APK's icon (use --icon)"
    end
  end
end

puts '=== PSDK Android Export ==='
puts "  Mode:        #{apk_mode ? 'Full APK' : 'Archive only'}"
puts "  Archive:     #{plain_mode ? 'plain .psa' : 'encrypted .epsa'}, #{compiled_mode ? 'compiled release (Release/)' : 'project sources'}"
if apk_mode
  puts "  App name:    #{app_name}"
  puts "  Package ID:  #{package_id}"
  puts "  Base APK:    #{base_apk_path}"
  puts "  Icon:        #{icon_path ? "#{icon_path}#{" (#{icon_source})" if icon_source}" : '(default)'}"
  puts "  Launch mode: #{debug_mode ? 'debug_uncompiled (--debug-mode)' : 'release'}"
elsif !plain_mode
  puts "  Cert source: #{cert_path ? "cert file #{cert_path}" : "APK #{base_apk_path}"}"
end
puts "  Output:      #{output_path}"
puts ''

# ---------------------------------------------------------------------------
# Step 0: Load the cert that will seed the KDF
# ---------------------------------------------------------------------------
#
# Two paths:
#   - APK mode: the cert comes from the keystore that will sign the APK. We
#     load (or generate) the keystore and extract the cert from it. Even with
#     a plain archive: the keystore still signs the APK.
#   - Archive mode: the cert is provided directly as a standalone PEM/DER
#     file or read from the player APK, no keystore needed. Used when the
#     maker doesn't have access to the signing keystore (e.g., CI-built
#     player APK). A plain archive needs none.

# --keystore is a PKCS12 file, or a directory holding (or to hold) an
# auto-generated debug.p12.
def resolve_keystore(path, password)
  path ||= File.join(Dir.home, '.psdk')
  return path unless File.directory?(path) || (!File.exist?(path) && File.extname(path).empty?)

  keystore_path = File.join(path, 'debug.p12')
  if File.exist?(keystore_path)
    puts "  Using existing keystore: #{keystore_path}"
  else
    FileUtils.mkdir_p(path)
    Pkcs12Cert.generate(p12_path: keystore_path, password: password)
    puts "  Generated PKCS12 keystore: #{keystore_path}"
    puts '  NOTE: back this file up. Losing it means future builds get a different'
    puts '        signing cert, and users with the previous build will have to'
    puts '        uninstall before installing the new one.'
  end
  keystore_path
end

begin
  signing_cert_der =
    if apk_mode
      keystore_path = resolve_keystore(opts[:keystore], keystore_pass)
      Pkcs12Cert.signing_cert_der(keystore_path, keystore_pass)
    elsif !plain_mode
      cert_path ? Pkcs12Cert.public_cert_der(cert_path) : Pkcs12Cert.cert_der_from_apk(base_apk_path)
    end
rescue Pkcs12Cert::KeystoreError => e
  abort e.message
end
puts "  Signing cert: #{signing_cert_der.bytesize} DER bytes loaded" if signing_cert_der
puts ''

# Ruby that compiled Release/Game.yarb: YARB magic, then major and minor (u32).
if compiled_mode
  yarb = File.binread('Release/Game.yarb', 64)
  abort 'Release/Game.yarb is not Ruby bytecode' unless yarb.start_with?('YARB')
  yarb_ruby = yarb.byteslice(4, 8).unpack('L<L<').join('.')
  yarb_platform = yarb.byteslice(36, 28)[/\A[^\0]*/]
  puts "  Bytecode:    Ruby #{yarb_ruby} (#{yarb_platform}): plays on the PSDK-android-ruby#{yarb_ruby} app only"
  puts ''
end

# ---------------------------------------------------------------------------
# Step 1: Build the game archive
# ---------------------------------------------------------------------------

archive_kind = plain_mode ? 'plain' : 'encrypted'
puts(apk_mode ? "[1/6] Building #{archive_kind} archive..." : "[1/1] Building #{archive_kind} archive...")

# Bundle the project's scripts into mega_script.deflate (see
# build_mega_script_deflate). The deflate is a portable Ruby-source bundle;
# on Android (where the archive is read via EpsaStream) it collapses a
# per-file decrypt-per-script storm into one decrypt of one ~1 MB blob
# followed by purely native-FS requires. Written to work_dir and added to
# the archive under its PSDK path, never to the project tree.
mega_script_path = nil
if compiled_mode
  puts '  Skipping mega_script.deflate (--compiled: the release ships its compiled scripts)'
elsif opts[:no_mega_script]
  puts '  Skipping mega_script.deflate (--no-mega-script)'
else
  mega_deflate, mega_count = build_mega_script_deflate
  mega_script_path = File.join(work_dir, 'mega_script.deflate')
  File.binwrite(mega_script_path, mega_deflate)
  puts "  #{MEGA_SCRIPT_ARCHIVE_PATH}: #{mega_count} entries, #{(mega_deflate.bytesize / 1024.0).round(1)} KiB"
end

# The project icon (project.studio's iconPath, or the release's game icon with
# --compiled, read above). Root files are not packed otherwise, so it goes in
# under STUDIO_ICON_ARCHIVE_PATH; the app's splash prefers it over the 32x32
# graphics/icons/game.png.
STUDIO_ICON_ARCHIVE_PATH = 'studio_icon.png'
puts "  #{STUDIO_ICON_ARCHIVE_PATH}: #{studio_icon_path ? "#{studio_icon_path} (#{studio_icon_source})" : '(no project icon)'}"

with_saves = opts[:with_saves]
folders = %w[graphics Fonts Data audio pokemonsdk scripts]
folders << 'Saves' if with_saves

# --compiled: every file of Release/, at the archive root. Left out: desktop
# saves (unless --with-saves) and what a desktop run leaves next to them.
RELEASE_SKIPPED = %w[Error.log .gameopts Saves/input.json].freeze
def release_files(with_saves)
  Dir.glob('**/*', File::FNM_DOTMATCH, base: RELEASE_DIR).reject do |rel|
    File.directory?(File.join(RELEASE_DIR, rel)) || RELEASE_SKIPPED.include?(rel) ||
      (!with_saves && rel.start_with?('Saves/'))
  end
end

# In archive mode the archive is the final artifact; in APK mode it's an
# intermediate that gets bundled into assets/ before rebuilding the APK.
archive_name = plain_mode ? 'game.psa' : 'game.epsa'
epsa_path = apk_mode ? File.join(work_dir, archive_name) : output_path
FileUtils.mkdir_p(File.dirname(epsa_path))

# A plain archive is the ZIP itself: write it in place, no copy.
zip_path = plain_mode ? epsa_path : File.join(work_dir, 'archive.zip')
FileUtils.rm_f(zip_path)
Zip::File.open(zip_path, create: true) do |zip|
  if compiled_mode
    files = release_files(with_saves)
    files.each { |rel| zip.add(rel, File.join(RELEASE_DIR, rel)) }
    # Keep the directories left empty (Saves/ without saves...): the game
    # may expect them.
    Dir.glob('**/', base: RELEASE_DIR).map { |dir| dir.chomp('/') }.reject(&:empty?).each do |dir|
      zip.mkdir(dir) unless files.any? { |rel| rel.start_with?("#{dir}/") }
    end
    zip.add(STUDIO_ICON_ARCHIVE_PATH, studio_icon_path) if studio_icon_path && !files.include?(STUDIO_ICON_ARCHIVE_PATH)
    next
  end

  glob_pattern = "{#{folders.join(',')}}/**/*"
  Dir.glob(glob_pattern).each do |file_or_dir|
    next if File.directory?(file_or_dir)
    # Saves/input.json holds desktop-side scancode bindings that don't match
    # Android SFML scancodes — bundling it would override the in-memory
    # defaults and silently misroute touch input. Let each install regenerate.
    next if file_or_dir == 'Saves/input.json'
    # pokemonsdk/scripts/scripts.dat is `RubyVM::InstructionSequence.to_binary`
    # output from a desktop pack_scripts run — bytecode is locked to the
    # Ruby version + CPU ABI it was generated on, so it cannot load on
    # Android (different arch). PSDK on Android would then trip on
    # ScriptLoad.rb:20's stale-cache delete (since DEFLATE_SCRIPT_PATH
    # is present too) and ENOENT against the read-only archive. The
    # portable `mega_script.deflate` built above covers the same use
    # case — drop the iseq binary unconditionally.
    next if file_or_dir == 'pokemonsdk/scripts/scripts.dat'
    # A mega_script.deflate on disk is stale (left by an older export):
    # only the one built above for this export goes in.
    next if file_or_dir == MEGA_SCRIPT_ARCHIVE_PATH

    zip.add(file_or_dir, file_or_dir)
  end
  zip.add(STUDIO_ICON_ARCHIVE_PATH, studio_icon_path) if studio_icon_path
  zip.add('Game.rb', 'Game.rb')
  zip.add(MEGA_SCRIPT_ARCHIVE_PATH, mega_script_path) if mega_script_path
end

if plain_mode
  puts "  Plain archive: #{File.size(epsa_path)} bytes"
else
  zip_data = File.binread(zip_path)
  puts "  Archive contents: #{zip_data.bytesize} bytes"

  kdf_version = EpsaKdf::CURRENT_KDF_VERSION
  n_chunks = EpsaWriter.write(
    epsa_path: epsa_path,
    plaintext: zip_data,
    signing_cert_der: signing_cert_der,
    kdf_version: kdf_version
  )
  puts "  Encrypted archive: #{File.size(epsa_path)} bytes " \
       "(v#{EpsaFormat::VERSION}, kdf=#{kdf_version}, chunks=#{n_chunks})"
end

# In archive mode we're done — the archive is the final artifact.
unless apk_mode
  puts ''
  puts '=== Done! ==='
  puts "  Output: #{epsa_path} (#{File.size(epsa_path)} bytes)"
  exit 0
end

# ---------------------------------------------------------------------------
# Step 2: Decompile the base APK with apktool
# ---------------------------------------------------------------------------

puts '[2/6] Decompiling base APK...'

decompiled_dir = File.join(work_dir, 'decompiled')
# The tools take their arguments as a list, without a shell: a path escaped for a POSIX shell
# (Shellwords) broke on Windows' cmd.exe as soon as it had a space or an accent, and Ruby finds
# and quotes Windows' .bat tools (apktool, apksigner) itself.
abort 'apktool decompile failed' unless system('apktool', 'd', base_apk_path, '-o', decompiled_dir, '-f', '-s', err: :out)

# Update versionCode so Android allows installing over a previous build
apktool_yml = File.join(decompiled_dir, 'apktool.yml')
version_code = Time.now.to_i / 60
apktool_content = File.read(apktool_yml)
apktool_content.sub!(/versionCode:\s*'?\d+'?/, "versionCode: #{version_code}")
File.write(apktool_yml, apktool_content)
puts "  versionCode: #{version_code}"

# ---------------------------------------------------------------------------
# Step 3: Modify app identity (manifest, resources, icon)
# ---------------------------------------------------------------------------

puts '[3/6] Customizing app identity...'

# 3a. AndroidManifest.xml — replace ALL occurrences of the old package name.
#     This covers: package="...", provider authorities, and auto-generated
#     permissions like DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION.
manifest_path = File.join(decompiled_dir, 'AndroidManifest.xml')
manifest = File.read(manifest_path)
old_package = manifest[/package="([^"]+)"/, 1]

manifest.gsub!(old_package, package_id)

# 3a-bis. Bake the launch mode into the APK. Read by EntryActivity at cold
# start (see EntryActivity.classicDefaultMode in the Android source).
# Absent the tag, the app defaults to RELEASE — so we ONLY inject it for
# --debug-mode builds; release-mode APKs stay byte-identical to before.
if debug_mode
  meta_tag = %(<meta-data android:name="com.psdk.CLASSIC_DEFAULT_MODE" )      \
             + %(android:value="debug_uncompiled"/>)
  if manifest.include?('com.psdk.CLASSIC_DEFAULT_MODE')
    # Re-export onto an already-debug APK: leave the existing tag alone.
    puts '  Manifest already carries CLASSIC_DEFAULT_MODE; left as-is.'
  elsif manifest.sub!(%r{(</application>)}, "    #{meta_tag}\n    \\1")
    puts '  Manifest: injected CLASSIC_DEFAULT_MODE=debug_uncompiled'
  else
    abort 'Failed to find </application> closing tag in AndroidManifest.xml; cannot inject debug-mode meta-data'
  end
end

File.write(manifest_path, manifest)
puts "  Package: #{old_package} -> #{package_id}"
puts "  Launch mode: #{debug_mode ? 'debug_uncompiled' : 'release'}"

# 3b. res/values/strings.xml — change app_name
strings_path = File.join(decompiled_dir, 'res', 'values', 'strings.xml')
if File.exist?(strings_path)
  strings = File.read(strings_path)
  strings.gsub!(%r{<string name="app_name">.*?</string>}, "<string name=\"app_name\">#{app_name}</string>")
  File.write(strings_path, strings)
  puts "  App name: #{app_name}"
end

# 3c. Replace icon if provided, in every drawable / mipmap directory that
# contains logo.png
if icon_path
  Dir.glob(File.join(decompiled_dir, 'res', '{drawable,mipmap}*', 'logo.png')).each do |target|
    FileUtils.cp(icon_path, target)
    puts "  Icon replaced: #{File.dirname(target)}"
  end
end

# ---------------------------------------------------------------------------
# Step 4: Inject the archive into assets/
# ---------------------------------------------------------------------------

puts '[4/6] Injecting game archive into assets...'

assets_dir = File.join(decompiled_dir, 'assets')
FileUtils.mkdir_p(assets_dir)
# The app plays the first archive it finds: drop the other kind a
# re-export onto an exported APK would leave behind.
(%w[game.epsa game.psa] - [archive_name]).each { |stale| FileUtils.rm_f(File.join(assets_dir, stale)) }
FileUtils.cp(epsa_path, File.join(assets_dir, archive_name))
puts "  Injected #{archive_name} into assets/"

# ---------------------------------------------------------------------------
# Step 5: Rebuild APK with apktool
# ---------------------------------------------------------------------------

puts '[5/6] Rebuilding APK...'

unsigned_apk = File.join(work_dir, 'unsigned.apk')
abort 'apktool rebuild failed' unless system('apktool', 'b', decompiled_dir, '-o', unsigned_apk, err: :out)

# Zipalign
aligned_apk = File.join(work_dir, 'aligned.apk')
abort 'zipalign failed' unless system('zipalign', '-f', '4', unsigned_apk, aligned_apk)

# ---------------------------------------------------------------------------
# Step 6: Sign the APK
# ---------------------------------------------------------------------------

puts '[6/6] Signing APK...'

# Keystore was already resolved/generated in step 0 — apksigner just uses it.
# The password goes through the environment, not the command line, so it
# doesn't show up in the process list.
FileUtils.mkdir_p(File.dirname(output_path))
unless system({ 'PSDK_KS_PASS' => keystore_pass },
              'apksigner', 'sign', '--ks', keystore_path, '--ks-pass', 'env:PSDK_KS_PASS', '--out', output_path, aligned_apk)
  abort 'apksigner signing failed'
end

puts ''
puts '=== Done! ==='
puts "  Output: #{output_path} (#{File.size(output_path)} bytes)"
puts "  Install: adb install #{output_path}"
