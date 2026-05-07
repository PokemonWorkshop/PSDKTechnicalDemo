# EPSA archive format constants — single source of truth.
#
# v4 streaming-decryption layout:
#
#   +-----------------------------------------------+  byte 0
#   | Header (HEADER_SIZE = 48 bytes)               |
#   +-----------------------------------------------+  byte HEADER_SIZE
#   | HMAC table (32 bytes per chunk)               |
#   +-----------------------------------------------+  byte HEADER_SIZE + hmac_table_len
#   | AES-256-CTR ciphertext (plaintext_len bytes)  |
#   +-----------------------------------------------+  EOF
#
# Header byte layout:
#
#   off  size  field
#     0     4  magic "PSAE"
#     4     4  version u32 LE   (= 4)
#     8     1  kdf_version      (currently 1)
#     9     3  reserved         (must be zero)
#    12     8  build_id         (random per archive)
#    20    16  nonce            (CTR base counter, random per archive)
#    36     4  chunk_log2 u32 LE  (chunk_size = 1 << chunk_log2; default 16 → 64 KiB)
#    40     8  plaintext_len u64 LE
#
# Crypto:
#
#   K_enc, K_mac = HKDF-SHA256(ikm = signing_cert_DER,
#                              salt = SALT,
#                              info = INFO_PFX || kdf_version || build_id || tag,
#                              length = 32)
#     where tag = "psdk-epsa-enc-v4" for K_enc, "psdk-epsa-mac-v4" for K_mac.
#
#   For chunk k (0 <= k < n_chunks), with chunk_size C = 1 << chunk_log2:
#     ptxt_k  = plaintext[k*C : min((k+1)*C, plaintext_len)]
#     iv_k    = (be_u128(nonce) + k * (C / 16)) mod 2^128, packed big-endian
#     ctxt_k  = AES-256-CTR(K_enc, iv_k).encrypt(ptxt_k)
#     hmac_k  = HMAC-SHA256(K_mac, u64_le(k) || ctxt_k)
#
#   The HMAC table at offset HEADER_SIZE is hmac_0 || hmac_1 || ... || hmac_{n-1}.
#   The ciphertext follows: ctxt_0 || ctxt_1 || ... || ctxt_{n-1}.
#
#   Encrypt-then-MAC: HMAC covers the chunk INDEX and the CIPHERTEXT (not the
#   plaintext). The chunk index in the HMAC input prevents reorder attacks.
#
# Why these choices:
#   - AES-CTR (vs CBC): trivially seekable per-block — required because PhysFS
#     reads the archive at random offsets when parsing the embedded ZIP central
#     directory. CTR has no padding, so plaintext_len = ciphertext length.
#   - Per-chunk HMAC (vs one tag at end): a single end-of-stream MAC would force
#     reading the whole archive on first byte to verify integrity, defeating
#     streaming. Per-chunk lets us verify-on-first-touch and skip already-
#     verified chunks.
#   - chunk_log2 = 16 (64 KiB): tradeoff between HMAC-table overhead (32 B per
#     chunk → 0.05% overhead at this size) and wasted decrypt for small reads.
#     ZIP central-directory reads are scattered; smaller chunks reduce per-read
#     amortization. 64 KiB matches typical ZIP read patterns and keeps the
#     table small (a 1 GB archive's table is 512 KiB).
#
# Compatibility: v3 archives are not readable by v4 code. The transition is a
# hard cutover — every consumer ships fresh with the new producer.

module EpsaFormat
  MAGIC                    = 'PSAE'
  VERSION                  = 4
  HEADER_SIZE              = 48
  KDF_VERSION_OFFSET       = 8
  RESERVED_OFFSET          = 9
  BUILD_ID_OFFSET          = 12
  NONCE_OFFSET             = 20
  CHUNK_LOG2_OFFSET        = 36
  PLAINTEXT_LEN_OFFSET     = 40

  BUILD_ID_SIZE            = 8
  NONCE_SIZE               = 16
  HMAC_SIZE                = 32

  DEFAULT_CHUNK_LOG2       = 16        # 64 KiB
  DEFAULT_CHUNK_SIZE       = 1 << DEFAULT_CHUNK_LOG2

  KDF_INFO_TAG_ENC         = 'psdk-epsa-enc-v4'
  KDF_INFO_TAG_MAC         = 'psdk-epsa-mac-v4'

  AES_BLOCK_SIZE           = 16

  # CTR counter arithmetic. The 16-byte nonce in the header is the initial
  # counter block; OpenSSL's aes-256-ctr increments it per AES block as a
  # big-endian uint128. To start decrypt/encrypt at chunk k, the counter
  # must equal `nonce + k * (chunk_size / AES_BLOCK_SIZE)` mod 2^128.
  def self.advance_be128(nonce_bytes, increment)
    raise ArgumentError, "expected #{NONCE_SIZE} bytes" unless nonce_bytes.bytesize == NONCE_SIZE
    v = (nonce_bytes.unpack1('H*').to_i(16) + increment) & ((1 << 128) - 1)
    [v.to_s(16).rjust(NONCE_SIZE * 2, '0')].pack('H*')
  end

  # Counter for AES block index `block_index` (0-based, global).
  def self.iv_for_block(nonce_bytes, block_index)
    advance_be128(nonce_bytes, block_index)
  end

  # Counter for chunk k (the first AES block of that chunk).
  def self.iv_for_chunk(nonce_bytes, chunk_index, chunk_size)
    advance_be128(nonce_bytes, chunk_index * (chunk_size / AES_BLOCK_SIZE))
  end
end
