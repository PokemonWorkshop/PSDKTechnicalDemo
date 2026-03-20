# Create the encrypted PSDK Source Archive for Android
# Needs the gem 'rubyzip'

require 'zip'
require 'openssl'
require 'tempfile'

ENCRYPTION_KEY = ['1f24dd020fb077983c537dd29af01b9188406ce835bca75567b54db9be9f83f9'].pack('H*')
EPSA_MAGIC = 'PSAE'
EPSA_VERSION = 2

unless ENCRYPTION_KEY.bytesize == 32
  STDERR.puts "ENCRYPTION_KEY must be exactly 32 bytes (got #{ENCRYPTION_KEY.bytesize})"
  exit 1
end

folders = ['graphics', 'Fonts', 'Data', 'audio', 'pokemonsdk', 'scripts']
folders = folders.concat(["Saves"]) if ARGV.include?('--with_saves')

no_encrypt = ARGV.include?('--no-encrypt')
BASE_NAME = ARGV.find { |arg| !arg.start_with?('--') } || "project"

# Build ZIP to a temp file (proper format with central directory, required by PhysFS)
tmp_zip = Tempfile.new(['psdk_archive', '.zip'], binmode: true)
begin
  tmp_zip.close
  Zip::File.open(tmp_zip.path, create: true) do |zip|
    glob_pattern = '{' + folders.join(',') + '}/**/*'
    Dir.glob(glob_pattern).each do |file_or_dir|
      next if File.directory?(file_or_dir)
      puts "Adding #{file_or_dir}"
      zip.add(file_or_dir, file_or_dir)
    end
    puts "Adding Game.rb"
    zip.add("Game.rb", "Game.rb")
  end
  zip_data = File.binread(tmp_zip.path)

  # Write plain .psa archive
  psa_name = "#{BASE_NAME}.psa"
  File.delete(psa_name) if File.exist?(psa_name)
  File.binwrite(psa_name, zip_data)
  puts "Plain archive written to #{psa_name} (#{File.size(psa_name)} bytes)"

  unless no_encrypt
    # Encrypt the ZIP data with AES-256-CBC
    begin
      hash = OpenSSL::Digest::SHA256.digest(zip_data)
      payload = hash + zip_data  # 32-byte SHA-256 hash prepended to ZIP data
      cipher = OpenSSL::Cipher::AES256.new(:CBC)
      cipher.encrypt
      cipher.key = ENCRYPTION_KEY
      iv = cipher.random_iv
      encrypted_data = cipher.update(payload) + cipher.final
    rescue OpenSSL::Cipher::CipherError => e
      STDERR.puts "Encryption failed: #{e.message}"
      exit 1
    end

    # Write the encrypted archive with header
    epsa_name = "#{BASE_NAME}.epsa"
    File.delete(epsa_name) if File.exist?(epsa_name)
    File.open(epsa_name, 'wb') do |f|
      f.write(EPSA_MAGIC)                  # 4 bytes: magic
      f.write([EPSA_VERSION].pack('V'))    # 4 bytes: version (uint32 LE)
      f.write(iv)                          # 16 bytes: IV
      f.write(encrypted_data)              # rest: ciphertext
    end
    puts "Encrypted archive written to #{epsa_name} (#{File.size(epsa_name)} bytes)"
  end
ensure
  tmp_zip.unlink
end
