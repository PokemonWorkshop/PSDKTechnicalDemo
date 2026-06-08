# Host-side counterpart to PSDK-android's libepsakdf.so.
#
# Produces byte-identical output to the native C implementation in
# PSDK-android/app/src/main/cpp/epsa_kdf.cpp.

require 'openssl'

require_relative 'epsa_format'

module EpsaKdf
  module_function

  CURRENT_KDF_VERSION = 1

  OBF_KEY = 0x7b

  # Original SALT bytes (32) XOR'd against OBF_KEY. Mirrors SALT_XOR in epsa_kdf.cpp.
  SALT_XOR = [
    '64ab5fc7696bc6c2d8b9cc9099549759' \
    'd15eef1f98d3d289ed0a37d198f4c0fe'
  ].pack('H*').freeze

  # "psdk-epsa-bundle" (16 bytes) XOR'd against OBF_KEY. Mirrors INFO_XOR in epsa_kdf.cpp.
  INFO_XOR = ['0b081f10561e0b081a56190e151f171e'].pack('H*').freeze

  BUILD_ID_SIZE = EpsaFormat::BUILD_ID_SIZE
  KEY_SIZE      = 32

  def deobfuscate(blob)
    blob.bytes.map { |b| b ^ OBF_KEY }.pack('C*')
  end

  def hkdf_extract(salt, ikm)
    OpenSSL::HMAC.digest('SHA256', salt, ikm)
  end

  def hkdf_expand(prk, info, length)
    raise ArgumentError, 'length too large' if length > 255 * 32

    out = String.new(encoding: Encoding::ASCII_8BIT)
    t = String.new(encoding: Encoding::ASCII_8BIT)
    counter = 1
    while out.bytesize < length
      t = OpenSSL::HMAC.digest('SHA256', prk, t + info + counter.chr)
      out << t
      counter += 1
    end
    out.byteslice(0, length)
  end

  def hkdf_sha256(ikm:, salt:, info:, length:)
    hkdf_expand(hkdf_extract(salt, ikm), info, length)
  end

  # Derive the 32-byte v4 K_enc and K_mac. Returns { enc_key:, mac_key: }.
  #
  # Two separate HKDF derivations off the same (cert_der, build_id, kdf_version),
  # distinguished by an `info`-suffix tag — see EpsaFormat for the layout.
  def derive_v4(cert_der, build_id, kdf_version = CURRENT_KDF_VERSION)
    raise ArgumentError, 'build_id must be 8 bytes' unless build_id.bytesize == BUILD_ID_SIZE
    raise ArgumentError, 'kdf_version out of byte range' unless (0..255).cover?(kdf_version)

    salt        = deobfuscate(SALT_XOR)
    info_prefix = deobfuscate(INFO_XOR) + kdf_version.chr + build_id

    enc_key = hkdf_sha256(ikm: cert_der, salt: salt,
                          info: info_prefix + EpsaFormat::KDF_INFO_TAG_ENC,
                          length: KEY_SIZE)
    mac_key = hkdf_sha256(ikm: cert_der, salt: salt,
                          info: info_prefix + EpsaFormat::KDF_INFO_TAG_MAC,
                          length: KEY_SIZE)

    { enc_key: enc_key, mac_key: mac_key }
  end
end
