# Streaming-format (.epsa v4) encrypter. Producer-side counterpart of
# PSDK-android's EpsaStream.

require 'openssl'

require_relative 'epsa_format'
require_relative 'epsa_kdf'

module EpsaWriter
  module_function

  # Encrypt `plaintext` (binary string) and write a v4 .epsa to `epsa_path`.
  # Returns the chunk count for logging.
  #
  # @param epsa_path        [String] destination
  # @param plaintext        [String] ASCII-8BIT bytes of the ZIP payload
  # @param signing_cert_der [String] APK signing cert DER bytes (KDF ikm)
  # @param kdf_version      [Integer] 0..255
  def write(epsa_path:, plaintext:, signing_cert_der:,
            kdf_version: EpsaKdf::CURRENT_KDF_VERSION,
            chunk_log2: EpsaFormat::DEFAULT_CHUNK_LOG2)
    build_id = OpenSSL::Random.random_bytes(EpsaFormat::BUILD_ID_SIZE)
    nonce    = OpenSSL::Random.random_bytes(EpsaFormat::NONCE_SIZE)
    keys     = EpsaKdf.derive_v4(signing_cert_der, build_id, kdf_version)

    chunk_size    = 1 << chunk_log2
    plaintext_len = plaintext.bytesize
    n_chunks      = (plaintext_len + chunk_size - 1) / chunk_size

    hmac_table      = String.new(encoding: Encoding::ASCII_8BIT)
    ciphertext_blob = String.new(encoding: Encoding::ASCII_8BIT)

    n_chunks.times do |k|
      ptxt = plaintext.byteslice(k * chunk_size, chunk_size) || ''.b
      iv   = EpsaFormat.iv_for_chunk(nonce, k, chunk_size)

      cipher = OpenSSL::Cipher.new('aes-256-ctr')
      cipher.encrypt
      cipher.key = keys[:enc_key]
      cipher.iv  = iv
      ctxt = cipher.update(ptxt) + cipher.final

      hmac = OpenSSL::HMAC.digest('SHA256', keys[:mac_key], [k].pack('Q<') + ctxt)

      hmac_table      << hmac
      ciphertext_blob << ctxt
    end

    File.open(epsa_path, 'wb') do |f|
      f.write(EpsaFormat::MAGIC)
      f.write([EpsaFormat::VERSION].pack('V'))
      f.write([kdf_version].pack('C'))
      f.write("\x00\x00\x00".b)
      f.write(build_id)
      f.write(nonce)
      f.write([chunk_log2].pack('V'))
      f.write([plaintext_len].pack('Q<'))
      f.write(hmac_table)
      f.write(ciphertext_blob)
    end

    n_chunks
  end
end
