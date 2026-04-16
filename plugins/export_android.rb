# Export a PSDK project as an Android APK
#
# Usage:
#   ruby export_android.rb MyGame --apk PSDK-base.apk [options]
#
# Required:
#   <name>                   Game/app name (first non-flag argument)
#   --apk <path>             Path to the base PSDK APK template
#
# Optional:
#   --icon <path>            Custom app icon (PNG, recommended 192x192)
#   --package <id>           Custom package ID (default: auto-generated from name)
#   --keystore <path>        Signing keystore path (default: auto-generated debug keystore)
#   --ks-pass <password>     Keystore password (default: "android")
#   --output <path>          Output APK path (default: <name>.apk)
#   --with-saves             Include Saves folder in the archive
#   --keep-tmp               Keep temporary files for debugging
#
# Requirements:
#   - apktool    (https://apktool.org)
#   - zipalign   (Android SDK build-tools)
#   - apksigner  (Android SDK build-tools)
#   - keytool    (JDK)
#   - gem: rubyzip

require 'zip'
require 'openssl'
require 'tempfile'
require 'fileutils'
require 'shellwords'

ENCRYPTION_KEY = ['1f24dd020fb077983c537dd29af01b9188406ce835bca75567b54db9be9f83f9'].pack('H*')
EPSA_MAGIC = 'PSAE'
EPSA_VERSION = 2

unless ENCRYPTION_KEY.bytesize == 32
  STDERR.puts "ENCRYPTION_KEY must be exactly 32 bytes (got #{ENCRYPTION_KEY.bytesize})"
  exit 1
end

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
keystore_pass  = parse_flag('--ks-pass') || 'android'
output_path    = parse_flag('--output')
with_saves     = parse_bool('--with-saves')
keep_tmp       = parse_bool('--keep-tmp')

app_name = ARGV.find { |arg| !arg.start_with?('--') }

abort "Usage: ruby export_android.rb <GameName> --apk <PSDK-base.apk> [options]" unless app_name
abort "Missing --apk <path>: path to the base PSDK APK template" unless base_apk_path
abort "Base APK not found: #{base_apk_path}" unless File.exist?(base_apk_path)
abort "Icon not found: #{icon_path}" if icon_path && !File.exist?(icon_path)

# ---------------------------------------------------------------------------
# Tool checks
# ---------------------------------------------------------------------------

def check_tool(name)
  system("which #{name} > /dev/null 2>&1") or abort "Required tool not found: #{name}\nPlease install it and ensure it's in your PATH."
end

check_tool('apktool')
check_tool('zipalign')
check_tool('apksigner')
check_tool('keytool')

# ---------------------------------------------------------------------------
# Derived values
# ---------------------------------------------------------------------------

safe_name = app_name.downcase.gsub(/[^a-z0-9]/, '')
abort "App name must contain at least one letter or digit" if safe_name.empty?

package_id  ||= "com.psdk.#{safe_name}"
output_path ||= "#{app_name.gsub(/\s+/, '_')}.apk"

tmp_dir = "tmp_export_android_#{$$}"

puts "=== PSDK Android Export ==="
puts "  App name:    #{app_name}"
puts "  Package ID:  #{package_id}"
puts "  Base APK:    #{base_apk_path}"
puts "  Icon:        #{icon_path || '(default)'}"
puts "  Output:      #{output_path}"
puts ""

# ---------------------------------------------------------------------------
# Step 1: Build encrypted .epsa archive
# ---------------------------------------------------------------------------

puts "[1/6] Building encrypted archive..."

folders = ['graphics', 'Fonts', 'Data', 'audio', 'pokemonsdk', 'scripts']
folders << 'Saves' if with_saves

tmp_zip = Tempfile.new(['psdk_archive', '.zip'], binmode: true)
epsa_path = File.join(tmp_dir, "game.epsa")

begin
  FileUtils.mkdir_p(tmp_dir)
  tmp_zip.close

  Zip::File.open(tmp_zip.path, create: true) do |zip|
    glob_pattern = '{' + folders.join(',') + '}/**/*'
    Dir.glob(glob_pattern).each do |file_or_dir|
      next if File.directory?(file_or_dir)
      zip.add(file_or_dir, file_or_dir)
    end
    zip.add("Game.rb", "Game.rb")
  end

  zip_data = File.binread(tmp_zip.path)
  puts "  Archive contents: #{zip_data.bytesize} bytes"

  hash = OpenSSL::Digest::SHA256.digest(zip_data)
  payload = hash + zip_data
  cipher = OpenSSL::Cipher::AES256.new(:CBC)
  cipher.encrypt
  cipher.key = ENCRYPTION_KEY
  iv = cipher.random_iv
  encrypted_data = cipher.update(payload) + cipher.final

  File.open(epsa_path, 'wb') do |f|
    f.write(EPSA_MAGIC)
    f.write([EPSA_VERSION].pack('V'))
    f.write(iv)
    f.write(encrypted_data)
  end
  puts "  Encrypted archive: #{File.size(epsa_path)} bytes"
ensure
  tmp_zip.unlink
end

# ---------------------------------------------------------------------------
# Step 2: Decompile the base APK with apktool
# ---------------------------------------------------------------------------

puts "[2/6] Decompiling base APK..."

decompiled_dir = File.join(tmp_dir, "decompiled")
unless system("apktool d #{base_apk_path.shellescape} -o #{decompiled_dir.shellescape} -f -s 2>&1")
  abort "apktool decompile failed"
end

# Update versionCode so Android allows installing over a previous build
apktool_yml = File.join(decompiled_dir, "apktool.yml")
version_code = Time.now.to_i / 60
apktool_content = File.read(apktool_yml)
apktool_content.sub!(/versionCode:\s*'?\d+'?/, "versionCode: #{version_code}")
File.write(apktool_yml, apktool_content)
puts "  versionCode: #{version_code}"

# ---------------------------------------------------------------------------
# Step 3: Modify app identity (manifest, resources, icon)
# ---------------------------------------------------------------------------

puts "[3/6] Customizing app identity..."

# 3a. AndroidManifest.xml — replace ALL occurrences of the old package name.
#     This covers: package="...", provider authorities, and auto-generated
#     permissions like DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION.
manifest_path = File.join(decompiled_dir, "AndroidManifest.xml")
manifest = File.read(manifest_path)
old_package = manifest[/package="([^"]+)"/, 1]

manifest.gsub!(old_package, package_id)
File.write(manifest_path, manifest)
puts "  Package: #{old_package} -> #{package_id}"

# 3b. res/values/strings.xml — change app_name
strings_path = File.join(decompiled_dir, "res", "values", "strings.xml")
if File.exist?(strings_path)
  strings = File.read(strings_path)
  strings.gsub!(/<string name="app_name">.*?<\/string>/, "<string name=\"app_name\">#{app_name}</string>")
  File.write(strings_path, strings)
  puts "  App name: #{app_name}"
end

# 3c. Replace icon if provided
if icon_path
  # Replace in all drawable directories that contain logo.png
  Dir.glob(File.join(decompiled_dir, "res", "drawable*")).each do |drawable_dir|
    target = File.join(drawable_dir, "logo.png")
    if File.exist?(target)
      FileUtils.cp(icon_path, target)
      puts "  Icon replaced: #{drawable_dir}"
    end
  end
  # Also check mipmap directories
  Dir.glob(File.join(decompiled_dir, "res", "mipmap*")).each do |mipmap_dir|
    target = File.join(mipmap_dir, "logo.png")
    if File.exist?(target)
      FileUtils.cp(icon_path, target)
      puts "  Icon replaced: #{mipmap_dir}"
    end
  end
end

# ---------------------------------------------------------------------------
# Step 4: Inject .epsa into assets/
# ---------------------------------------------------------------------------

puts "[4/6] Injecting game archive into assets..."

assets_dir = File.join(decompiled_dir, "assets")
FileUtils.mkdir_p(assets_dir)
FileUtils.cp(epsa_path, File.join(assets_dir, "game.epsa"))
puts "  Injected game.epsa into assets/"

# ---------------------------------------------------------------------------
# Step 5: Rebuild APK with apktool
# ---------------------------------------------------------------------------

puts "[5/6] Rebuilding APK..."

unsigned_apk = File.join(tmp_dir, "unsigned.apk")
unless system("apktool b #{decompiled_dir.shellescape} -o #{unsigned_apk.shellescape} 2>&1")
  abort "apktool rebuild failed"
end

# Zipalign
aligned_apk = File.join(tmp_dir, "aligned.apk")
unless system("zipalign -f 4 #{unsigned_apk.shellescape} #{aligned_apk.shellescape}")
  abort "zipalign failed"
end

# ---------------------------------------------------------------------------
# Step 6: Sign the APK
# ---------------------------------------------------------------------------

puts "[6/6] Signing APK..."

# Use or generate a persistent debug keystore when none provided
unless keystore_path
  default_keystore_dir = File.join(Dir.home, ".android")
  keystore_path = File.join(default_keystore_dir, "debug.keystore")
  unless File.exist?(keystore_path)
    FileUtils.mkdir_p(default_keystore_dir)
    unless system(
      "keytool -genkey -v -keystore #{keystore_path.shellescape} " \
      "-alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 " \
      "-storepass #{keystore_pass.shellescape} " \
      "-dname 'CN=PSDK, O=PSDK' 2>&1"
    )
      abort "keytool keystore generation failed"
    end
    puts "  Generated debug keystore: #{keystore_path}"
  else
    puts "  Using existing debug keystore: #{keystore_path}"
  end
end

unless system(
  "apksigner sign " \
  "--ks #{keystore_path.shellescape} " \
  "--ks-pass pass:#{keystore_pass.shellescape} " \
  "--out #{output_path.shellescape} " \
  "#{aligned_apk.shellescape}"
)
  abort "apksigner signing failed"
end

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

unless keep_tmp
  FileUtils.rm_rf(tmp_dir)
end

puts ""
puts "=== Done! ==="
puts "  Output: #{output_path} (#{File.size(output_path)} bytes)"
puts "  Install: adb install #{output_path}"
