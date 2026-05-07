# Extract the signing certificate (DER bytes) from a PKCS12 keystore.
#
# We deliberately depend only on Ruby's built-in OpenSSL — no shelling out to
# `keytool`. That means the host keystore must be in PKCS12 format. JKS users
# convert their keystore once outside this pipeline.

require 'openssl'

module Pkcs12Cert
  module_function

  KeystoreError = Class.new(StandardError)

  # @param p12_path  [String] path to the .p12 / .pfx keystore
  # @param password  [String] keystore password
  # @return [String] DER-encoded X.509 certificate bytes
  def signing_cert_der(p12_path, password)
    raise KeystoreError, "Keystore not found: #{p12_path}" unless File.exist?(p12_path)

    begin
      p12 = OpenSSL::PKCS12.new(File.binread(p12_path), password)
    rescue OpenSSL::PKCS12::PKCS12Error => e
      raise KeystoreError,
            "Failed to read PKCS12 keystore #{p12_path}: #{e.message}.\n" \
            'The keystore must be PKCS12 format (.p12 / .pfx). ' \
            'JKS keystores are not supported by this pipeline.'
    end

    raise KeystoreError, "PKCS12 keystore #{p12_path} contains no certificate" unless p12.certificate

    p12.certificate.to_der
  end

  # Extract the signing certificate from an Android APK and return its DER bytes.
  #
  # Tries the APK Signature Scheme V3.1 / V3 / V2 block first (the canonical
  # source — this is exactly what context.packageManager.getPackageInfo(...).
  # signingInfo.signingCertificateHistory[0].toByteArray() returns at runtime).
  # Falls back to V1 META-INF/*.RSA for old APKs that only have V1 signing.
  #
  # @param apk_path [String] path to the .apk file
  # @return [String] DER-encoded X.509 certificate bytes
  def cert_der_from_apk(apk_path)
    raise KeystoreError, "APK file not found: #{apk_path}" unless File.exist?(apk_path)

    require_relative 'apk_signing_block'

    # V2/V3 path — the modern, canonical source. Apksigner since AGP 7.x produces
    # V2+V3 only by default; META-INF/*.RSA is absent.
    begin
      cert = ApkSigningBlock.first_cert_der(apk_path)
      return cert if cert
    rescue ApkSigningBlock::ParseError
      # No V2/V3 block — fall through to V1.
    end

    # V1 fallback — META-INF/<alias>.RSA holds a PKCS#7 SignedData with the cert.
    require 'zip'
    Zip::File.open(apk_path) do |zip|
      rsa_entry = zip.glob('META-INF/*.RSA').first \
                || zip.glob('META-INF/*.EC').first \
                || zip.glob('META-INF/*.DSA').first
      if rsa_entry.nil?
        raise KeystoreError,
              "No V2/V3 signing block AND no V1 META-INF/*.RSA found in #{apk_path}.\n" \
              'The APK must be signed by apksigner (or jarsigner) before its cert can ' \
              'be extracted. Build a signed APK first.'
      end
      pkcs7_data = rsa_entry.get_input_stream.read

      begin
        pkcs7 = OpenSSL::PKCS7.new(pkcs7_data)
      rescue OpenSSL::PKCS7::PKCS7Error => e
        raise KeystoreError, "Failed to parse PKCS#7 in #{apk_path}!#{rsa_entry.name}: #{e.message}"
      end

      certs = pkcs7.certificates
      raise KeystoreError, "PKCS#7 in #{apk_path}!#{rsa_entry.name} contains no certificates" if certs.nil? || certs.empty?

      certs.first.to_der
    end
  end

  # Read a standalone X.509 certificate (PEM or DER) and return its DER bytes.
  # Used by the maker-side "epsa-only" flow where the maker doesn't have access
  # to the CI signing keystore — only the public cert that the eventual APK
  # will be signed with.
  #
  # @param cert_path [String] path to the .pem / .crt / .der / .cer file
  # @return [String] DER-encoded X.509 certificate bytes
  def public_cert_der(cert_path)
    raise KeystoreError, "Cert file not found: #{cert_path}" unless File.exist?(cert_path)

    raw = File.binread(cert_path)
    cert = begin
      # PEM: base64 wrapped in BEGIN/END markers. Try this first — DER bytes
      # that happen to start with 0x2d would be ambiguous, but in practice
      # X.509 DER always starts with 0x30 (SEQUENCE) so disambiguation is clean.
      OpenSSL::X509::Certificate.new(raw)
    rescue OpenSSL::X509::CertificateError => e
      raise KeystoreError,
            "Failed to parse certificate at #{cert_path}: #{e.message}.\n" \
            'The file must be a valid X.509 certificate in PEM or DER format.'
    end

    cert.to_der
  end

  # Generate a new PKCS12 keystore with a self-signed RSA-2048 cert.
  # Used when the user doesn't supply --keystore (replaces the previous
  # `keytool -genkey` shell-out so we have no PATH dependency on keytool).
  #
  # @param p12_path [String] destination path
  # @param password [String] keystore password
  # @param dn       [String] distinguished name (e.g. "CN=PSDK, O=PSDK")
  def generate(p12_path:, password:, dn: 'CN=PSDK, O=PSDK', validity_years: 30)
    key  = OpenSSL::PKey::RSA.new(2048)
    name = OpenSSL::X509::Name.parse(dn)

    cert = OpenSSL::X509::Certificate.new
    cert.version    = 2
    cert.serial     = OpenSSL::BN.rand(159) # 159 bits — sub-160 to stay positive
    cert.subject    = name
    cert.issuer     = name
    cert.public_key = key.public_key
    cert.not_before = Time.now - 60
    cert.not_after  = cert.not_before + (validity_years * 365 * 24 * 60 * 60)

    ef = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate  = cert
    cert.add_extension(ef.create_extension('basicConstraints', 'CA:TRUE', true))
    cert.add_extension(ef.create_extension('subjectKeyIdentifier', 'hash', false))

    cert.sign(key, OpenSSL::Digest.new('SHA256'))

    p12 = OpenSSL::PKCS12.create(password, 'androiddebugkey', key, cert)
    File.binwrite(p12_path, p12.to_der)
    p12_path
  end
end
