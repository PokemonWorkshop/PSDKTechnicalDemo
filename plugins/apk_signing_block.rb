# Parser for the APK Signing Block (V2 / V3 / V3.1).
#
# Modern APKs (apksigner default since AGP 7.x) ship without V1 (JAR) signing.
# The cert lives in a binary block at the end of the file, between the last
# ZIP entry and the central directory. Android's PackageManager reads the cert
# from here too — so what we extract here matches exactly what
# context.packageManager.getPackageInfo(...).signingInfo.signingCertificateHistory[0]
# returns at runtime, byte-for-byte.
#
# Spec: https://source.android.com/docs/security/features/apksigning/v2
#
# All multi-byte fields are little-endian.
#
# Layout:
#   ZIP entries
#   APK Signing Block:
#     uint64  size (excludes this leading uint64 — i.e. counts everything below)
#     pairs:
#       uint64  pair_length (covers the next ID + value)
#       uint32  ID                      (V2: 0x7109871a, V3: 0xf05368c0, V3.1: 0x1b93ad61)
#       bytes   value
#       ...repeated...
#     uint64  size (same value as the leading size)
#     16 bytes magic = "APK Sig Block 42"
#   ZIP central directory
#   ZIP end-of-central-directory record (EOCD)

module ApkSigningBlock
  module_function

  ParseError = Class.new(StandardError)

  EOCD_MAGIC      = 0x06054b50
  APK_SIG_MAGIC   = 'APK Sig Block 42'.b.freeze
  SCHEME_V2_ID    = 0x7109871a
  SCHEME_V3_ID    = 0xf05368c0
  SCHEME_V3_1_ID  = 0x1b93ad61

  # Returns the DER bytes of the first signer's first cert, matching what
  # Android's signingCertificateHistory[0] returns at runtime.
  # Raises ParseError if no V2/V3/V3.1 block is found.
  def first_cert_der(apk_path)
    File.open(apk_path, 'rb') do |io|
      cd_offset = find_central_directory_offset(io)
      raise ParseError, "EOCD record not found in #{apk_path}" unless cd_offset

      block = read_apk_signing_block(io, cd_offset)
      raise ParseError, "APK Signing Block not found in #{apk_path}" unless block

      # Prefer V3.1 > V3 > V2 (matching Android's preference order).
      [SCHEME_V3_1_ID, SCHEME_V3_ID, SCHEME_V2_ID].each do |id|
        scheme = find_id_value(block, id)
        next unless scheme

        cert = first_cert_from_scheme_block(scheme)
        return cert if cert
      end

      raise ParseError, "No V2 or V3 APK Signature Scheme block found in #{apk_path}"
    end
  end

  # Search the last ~64 KB of the file for the EOCD magic and return the
  # central-directory offset stored within. ZIP allows up to a 65535-byte
  # comment after EOCD, so we read enough to cover that.
  def find_central_directory_offset(io)
    size = io.size
    search_size = [size, 22 + 65_535].min
    io.seek(size - search_size)
    tail = io.read(search_size)

    eocd_pos = nil
    (search_size - 22).downto(0) do |i|
      next unless tail.byteslice(i, 4)&.unpack1('V') == EOCD_MAGIC

      eocd_pos = i
      break
    end
    return nil unless eocd_pos

    tail.byteslice(eocd_pos + 16, 4).unpack1('V')
  end

  # Read the APK Signing Block by walking back from the central directory.
  # Returns the inner pair-list bytes (without the leading/trailing size or
  # the trailing magic), or nil if no signing block is present.
  def read_apk_signing_block(io, cd_offset)
    return nil if cd_offset < 32 # min: 8 + 0 + 8 + 16

    io.seek(cd_offset - 16)
    return nil unless io.read(16) == APK_SIG_MAGIC

    io.seek(cd_offset - 24)
    size = io.read(8).unpack1('Q<')
    return nil if size < 24 || cd_offset < size + 8

    block_start = cd_offset - 8 - size
    io.seek(block_start)
    leading_size = io.read(8).unpack1('Q<')
    return nil unless leading_size == size

    # Pair-list bytes = block content minus trailing size (8) and magic (16).
    io.read(size - 24)
  end

  # Walk the (uint64-length)(uint32-id)(bytes-value) pairs and return the value
  # for the requested ID, or nil if not found.
  def find_id_value(block, target_id)
    pos = 0
    while pos + 12 <= block.bytesize
      length = block.byteslice(pos, 8).unpack1('Q<')
      pos += 8
      return nil if length < 4 || pos + length > block.bytesize

      id = block.byteslice(pos, 4).unpack1('V')
      return block.byteslice(pos + 4, length - 4) if id == target_id

      pos += length
    end
    nil
  end

  # Parse the inner of a V2/V3/V3.1 scheme block.
  #
  # Common outer shape (uint32 = u4):
  #   block:
  #     u4 signers_list_length
  #     [for each signer]
  #       u4 signer_length
  #       [signer body]
  #
  # Signer body (we only need signed_data, which is the first field):
  #   u4 signed_data_length
  #   [signed_data body]
  #   ...other fields we ignore...
  #
  # signed_data body (V2 and V3 share the first two fields):
  #   u4 digests_length [digests]
  #   u4 certificates_list_length
  #     u4 cert_length
  #     [cert DER bytes]
  #     ...
  #   ...other fields we ignore...
  def first_cert_from_scheme_block(block)
    p = 0

    return nil if p + 4 > block.bytesize
    signers_list_len = block.byteslice(p, 4).unpack1('V'); p += 4
    return nil if p + signers_list_len > block.bytesize

    return nil if p + 4 > block.bytesize
    signer_len = block.byteslice(p, 4).unpack1('V'); p += 4
    return nil if p + signer_len > block.bytesize
    signer_end = p + signer_len

    return nil if p + 4 > signer_end
    sd_len = block.byteslice(p, 4).unpack1('V'); p += 4
    return nil if p + sd_len > signer_end
    sd_end = p + sd_len

    sd_p = p
    return nil if sd_p + 4 > sd_end
    digests_len = block.byteslice(sd_p, 4).unpack1('V'); sd_p += 4 + digests_len
    return nil if sd_p > sd_end

    return nil if sd_p + 4 > sd_end
    certs_list_len = block.byteslice(sd_p, 4).unpack1('V'); sd_p += 4
    return nil if sd_p + certs_list_len > sd_end

    return nil if sd_p + 4 > sd_end
    cert_len = block.byteslice(sd_p, 4).unpack1('V'); sd_p += 4
    return nil if sd_p + cert_len > sd_end

    block.byteslice(sd_p, cert_len)
  end
end
