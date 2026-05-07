# Export a PSDK project as an Android APK, or as a standalone .epsa archive.
#
# Two modes:
#
# 1. Full APK export (default):
#      ruby export_android.rb MyGame --apk PSDK-base.apk [options]
#    Builds, signs, and outputs a complete .apk. Requires a PKCS12 keystore.
#    The .epsa is bundled inside the APK and encrypted with a key derived from
#    the keystore's signing certificate.
#
# 2. EPSA-only export (--epsa-only):
#      ruby export_android.rb MyGame --epsa-only --apk player.apk  --output mygame.epsa
#      ruby export_android.rb MyGame --epsa-only --cert player.crt --output mygame.epsa
#    Produces just the encrypted .epsa file. No apktool, no apksigner.
#    The cert is the *public* X.509 cert of the eventual APK that will play this
#    archive — no private key needed, no keystore needed. Either:
#      --apk <path-to-apk>  : extract the cert directly from the player APK's
#                             META-INF/ (the easy path — Pokemon Studio already
#                             has the player APK for distribution).
#      --cert <path-to-cert>: hand the cert as a separate PEM/DER file.
#    Intended for makers who don't have direct access to the signing keystore
#    (for example, when the player APK is built by a CI server).
#
# Required (full APK mode):
#   <name>                   Game/app name (first non-flag argument)
#   --apk <path>             Path to the base PSDK APK template
#
# Required (epsa-only mode):
#   <name>                   Game/app name (first non-flag argument)
#   --epsa-only              Skip APK build/sign, output just the .epsa
#   --apk <path> | --cert <path>   Source of the target APK's signing cert (exactly one)
#   --output <path>          Destination .epsa path
#
# Optional:
#   --icon <path>            Custom app icon (PNG, recommended 192x192) — APK mode only
#   --package <id>           Custom package ID (default: auto-generated) — APK mode only
#   --keystore <path>        Explicit PKCS12 keystore path — APK mode only
#                            If unset, an auto-generated keystore is used (see --keystore-dir).
#   --keystore-dir <dir>     Directory holding (or to hold) the auto-generated keystore.
#                            Used as <dir>/debug.p12 when --keystore is not provided.
#                            Default: ~/.psdk/. Pokemon Studio sets this to a project-relative
#                            location so the keystore travels with the project. — APK mode only
#   --ks-pass <password>     Keystore password (default: "android") — APK mode only
#   --output <path>          Output path (default: <name>.apk in APK mode, required in epsa-only mode)
#   --with-saves             Include Saves folder in the archive
#   --keep-tmp               Keep temporary files for debugging — APK mode only
#
# Requirements (full APK mode):
#   - apktool    (https://apktool.org)
#   - zipalign   (Android SDK build-tools)
#   - apksigner  (Android SDK build-tools)
#   - gem: rubyzip
#
# Requirements (epsa-only mode):
#   - gem: rubyzip
#
# Keystore note: APK mode reads the signing certificate via Ruby's OpenSSL
# (PKCS12 only) and binds the .epsa encryption key to it via HKDF. JKS or BKS
# keystores are not supported — convert them once to PKCS12 outside this
# pipeline. EPSA-only mode bypasses this entirely; it just reads a standalone
# public cert.

require 'zip'
require 'openssl'
require 'tempfile'
require 'fileutils'
require 'shellwords'

require_relative 'epsa_kdf'
require_relative 'pkcs12_cert'

EPSA_MAGIC = 'PSAE'
EPSA_VERSION = 3

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

def parse_flag(flag)
  idx = ARGV.index(flag)
  return nil unless idx

  ARGV.delete_at(idx)
  value = ARGV.delete_at(idx)
  abort "#{flag} requires a value" unless value
  value
end

def parse_bool(flag)
  idx = ARGV.index(flag)
  return false unless idx

  ARGV.delete_at(idx)
  true
end

base_apk_path  = parse_flag('--apk')
icon_path      = parse_flag('--icon')
package_id     = parse_flag('--package')
keystore_path  = parse_flag('--keystore')
keystore_dir   = parse_flag('--keystore-dir')
keystore_pass  = parse_flag('--ks-pass') || 'android'
output_path    = parse_flag('--output')
cert_path      = parse_flag('--cert')
with_saves     = parse_bool('--with-saves')
keep_tmp       = parse_bool('--keep-tmp')
epsa_only_mode = parse_bool('--epsa-only')

app_name = ARGV.find { |arg| !arg.start_with?('--') }

abort 'Usage:
  Full APK:    ruby export_android.rb <GameName> --apk <PSDK-base.apk> [options]
  EPSA only:   ruby export_android.rb <GameName> --epsa-only --apk  <player.apk> --output <out.epsa>
               ruby export_android.rb <GameName> --epsa-only --cert <cert.pem>   --output <out.epsa>' unless app_name

if epsa_only_mode
  abort '--epsa-only requires either --apk <path-to-target-apk> or --cert <path-to-public-cert>' \
    unless cert_path || base_apk_path
  abort '--epsa-only: pass exactly one of --apk or --cert (not both)' if cert_path && base_apk_path
  abort '--epsa-only requires --output <path-to-output-epsa>' unless output_path
  abort "Cert file not found: #{cert_path}" if cert_path && !File.exist?(cert_path)
  abort "APK file not found: #{base_apk_path}" if base_apk_path && !File.exist?(base_apk_path)
  abort '--epsa-only is incompatible with --keystore / --keystore-dir / --icon / --package' \
    if keystore_path || keystore_dir || icon_path || package_id
else
  abort 'Missing --apk <path>: path to the base PSDK APK template' unless base_apk_path
  abort "Base APK not found: #{base_apk_path}" unless File.exist?(base_apk_path)
  abort "Icon not found: #{icon_path}" if icon_path && !File.exist?(icon_path)
  abort '--cert is only valid in --epsa-only mode' if cert_path
  abort '--keystore-dir is ignored when --keystore is also provided' if keystore_path && keystore_dir
end

# ---------------------------------------------------------------------------
# Tool checks
# ---------------------------------------------------------------------------

def check_tool(name)
  system("which #{name} > /dev/null 2>&1") or abort "Required tool not found: #{name}\nPlease install it and ensure it's in your PATH."
end

unless epsa_only_mode
  check_tool('apktool')
  check_tool('zipalign')
  check_tool('apksigner')
end

# ---------------------------------------------------------------------------
# Derived values
# ---------------------------------------------------------------------------

safe_name = app_name.downcase.gsub(/[^a-z0-9]/, '')
abort 'App name must contain at least one letter or digit' if safe_name.empty?

package_id  ||= "com.psdk.#{safe_name}" unless epsa_only_mode
output_path ||= "#{app_name.gsub(/\s+/, '_')}.apk" unless epsa_only_mode

tmp_dir = "tmp_export_android_#{$$}"

puts '=== PSDK Android Export ==='
puts "  Mode:        #{epsa_only_mode ? 'EPSA-only' : 'Full APK'}"
puts "  App name:    #{app_name}"
puts "  Package ID:  #{package_id}" unless epsa_only_mode
puts "  Base APK:    #{base_apk_path}" unless epsa_only_mode
puts "  Icon:        #{icon_path || '(default)'}" unless epsa_only_mode
puts "  Cert source: #{cert_path ? "cert file #{cert_path}" : "APK #{base_apk_path}"}" if epsa_only_mode
puts "  Output:      #{output_path}"
puts ''

# ---------------------------------------------------------------------------
# Step 0: Load the cert that will seed the KDF
# ---------------------------------------------------------------------------
#
# Two paths:
#   - Full APK mode: the cert comes from the keystore that will sign the APK.
#     We load (or generate) the keystore and extract the cert from it.
#   - EPSA-only mode: the cert is provided directly as a standalone PEM/DER
#     file, no keystore needed. Used when the maker doesn't have access to the
#     signing keystore (e.g., CI-built player APK).

signing_cert_der =
  if epsa_only_mode
    begin
      cert_path ? Pkcs12Cert.public_cert_der(cert_path) : Pkcs12Cert.cert_der_from_apk(base_apk_path)
    rescue Pkcs12Cert::KeystoreError => e
      abort e.message
    end
  else
    unless keystore_path
      auto_keystore_dir = keystore_dir || File.join(Dir.home, '.psdk')
      keystore_path = File.join(auto_keystore_dir, 'debug.p12')
      if File.exist?(keystore_path)
        puts "  Using existing keystore: #{keystore_path}"
      else
        FileUtils.mkdir_p(auto_keystore_dir)
        Pkcs12Cert.generate(p12_path: keystore_path, password: keystore_pass)
        puts "  Generated PKCS12 keystore: #{keystore_path}"
        puts '  NOTE: back this file up. Losing it means future builds get a different'
        puts '        signing cert, and users with the previous build will have to'
        puts '        uninstall before installing the new one.'
      end
    end
    begin
      Pkcs12Cert.signing_cert_der(keystore_path, keystore_pass)
    rescue Pkcs12Cert::KeystoreError => e
      abort e.message
    end
  end
puts "  Signing cert: #{signing_cert_der.bytesize} DER bytes loaded"
puts ''

# ---------------------------------------------------------------------------
# Step 1: Build encrypted .epsa archive
# ---------------------------------------------------------------------------

puts(epsa_only_mode ? '[1/1] Building encrypted archive...' : '[1/6] Building encrypted archive...')

folders = %w[graphics Fonts Data audio pokemonsdk scripts]
folders << 'Saves' if with_saves

tmp_zip = Tempfile.new(['psdk_archive', '.zip'], binmode: true)
# In epsa-only mode the .epsa is the final artifact; in full APK mode it's an
# intermediate that gets bundled into assets/ before rebuilding the APK.
epsa_path = epsa_only_mode ? output_path : File.join(tmp_dir, 'game.epsa')

begin
  FileUtils.mkdir_p(tmp_dir) unless epsa_only_mode
  FileUtils.mkdir_p(File.dirname(epsa_path)) if epsa_only_mode && !File.dirname(epsa_path).empty?
  tmp_zip.close

  Zip::File.open(tmp_zip.path, create: true) do |zip|
    glob_pattern = "{#{folders.join(',')}}/**/*"
    Dir.glob(glob_pattern).each do |file_or_dir|
      next if File.directory?(file_or_dir)
      # Saves/input.json holds desktop-side scancode bindings that don't match
      # Android SFML scancodes — bundling it would override the in-memory
      # defaults and silently misroute touch input. Let each install regenerate.
      next if file_or_dir == 'Saves/input.json'

      zip.add(file_or_dir, file_or_dir)
    end
    zip.add('Game.rb', 'Game.rb')
  end

  zip_data = File.binread(tmp_zip.path)
  puts "  Archive contents: #{zip_data.bytesize} bytes"

  hash = OpenSSL::Digest::SHA256.digest(zip_data)
  payload = hash + zip_data

  build_id = OpenSSL::Random.random_bytes(8)
  kdf_version = EpsaKdf::CURRENT_KDF_VERSION
  key = EpsaKdf.derive(signing_cert_der, build_id, kdf_version)

  cipher = OpenSSL::Cipher.new('aes-256-cbc')
  cipher.encrypt
  cipher.key = key
  iv = cipher.random_iv
  encrypted_data = cipher.update(payload) + cipher.final

  # v3 header: magic (4) | version (4) | kdf_version (1) | reserved (3) | build_id (8) | IV (16)
  File.open(epsa_path, 'wb') do |f|
    f.write(EPSA_MAGIC)
    f.write([EPSA_VERSION].pack('V'))
    f.write([kdf_version].pack('C'))
    f.write("\x00\x00\x00".b)
    f.write(build_id)
    f.write(iv)
    f.write(encrypted_data)
  end
  puts "  Encrypted archive: #{File.size(epsa_path)} bytes (v#{EPSA_VERSION}, kdf=#{kdf_version})"
ensure
  tmp_zip.unlink
end

# In epsa-only mode we're done — the archive is the final artifact.
if epsa_only_mode
  puts ''
  puts '=== Done! ==='
  puts "  Output: #{epsa_path} (#{File.size(epsa_path)} bytes)"
  exit 0
end

# ---------------------------------------------------------------------------
# Step 2: Decompile the base APK with apktool
# ---------------------------------------------------------------------------

puts '[2/6] Decompiling base APK...'

decompiled_dir = File.join(tmp_dir, 'decompiled')
abort 'apktool decompile failed' unless system("apktool d #{base_apk_path.shellescape} -o #{decompiled_dir.shellescape} -f -s 2>&1")

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
File.write(manifest_path, manifest)
puts "  Package: #{old_package} -> #{package_id}"

# 3b. res/values/strings.xml — change app_name
strings_path = File.join(decompiled_dir, 'res', 'values', 'strings.xml')
if File.exist?(strings_path)
  strings = File.read(strings_path)
  strings.gsub!(%r{<string name="app_name">.*?</string>}, "<string name=\"app_name\">#{app_name}</string>")
  File.write(strings_path, strings)
  puts "  App name: #{app_name}"
end

# 3c. Replace icon if provided
if icon_path
  # Replace in all drawable directories that contain logo.png
  Dir.glob(File.join(decompiled_dir, 'res', 'drawable*')).each do |drawable_dir|
    target = File.join(drawable_dir, 'logo.png')
    if File.exist?(target)
      FileUtils.cp(icon_path, target)
      puts "  Icon replaced: #{drawable_dir}"
    end
  end
  # Also check mipmap directories
  Dir.glob(File.join(decompiled_dir, 'res', 'mipmap*')).each do |mipmap_dir|
    target = File.join(mipmap_dir, 'logo.png')
    if File.exist?(target)
      FileUtils.cp(icon_path, target)
      puts "  Icon replaced: #{mipmap_dir}"
    end
  end
end

# ---------------------------------------------------------------------------
# Step 4: Inject .epsa into assets/
# ---------------------------------------------------------------------------

puts '[4/6] Injecting game archive into assets...'

assets_dir = File.join(decompiled_dir, 'assets')
FileUtils.mkdir_p(assets_dir)
FileUtils.cp(epsa_path, File.join(assets_dir, 'game.epsa'))
puts '  Injected game.epsa into assets/'

# ---------------------------------------------------------------------------
# Step 5: Rebuild APK with apktool
# ---------------------------------------------------------------------------

puts '[5/6] Rebuilding APK...'

unsigned_apk = File.join(tmp_dir, 'unsigned.apk')
abort 'apktool rebuild failed' unless system("apktool b #{decompiled_dir.shellescape} -o #{unsigned_apk.shellescape} 2>&1")

# Zipalign
aligned_apk = File.join(tmp_dir, 'aligned.apk')
abort 'zipalign failed' unless system("zipalign -f 4 #{unsigned_apk.shellescape} #{aligned_apk.shellescape}")

# ---------------------------------------------------------------------------
# Step 6: Sign the APK
# ---------------------------------------------------------------------------

puts '[6/6] Signing APK...'

# Keystore was already resolved/generated in step 0 — apksigner just uses it.

unless system(
  'apksigner sign ' \
  "--ks #{keystore_path.shellescape} " \
  "--ks-pass pass:#{keystore_pass.shellescape} " \
  "--out #{output_path.shellescape} " \
  "#{aligned_apk.shellescape}"
)
  abort 'apksigner signing failed'
end

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

FileUtils.rm_rf(tmp_dir) unless keep_tmp

puts ''
puts '=== Done! ==='
puts "  Output: #{output_path} (#{File.size(output_path)} bytes)"
puts "  Install: adb install #{output_path}"
