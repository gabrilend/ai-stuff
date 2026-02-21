# Issue 16-004: HTTPS with Self-Signed Certificates

## Priority
Medium (Security Infrastructure)

## Current Behavior

No HTTPS infrastructure exists for the file server. All prior HTML generation serves static files that don't require encryption because they're served from the same origin or as local files.

## Intended Behavior

Generate and use self-signed SSL/TLS certificates for secure file transfer over WiFi. Users will see browser warnings but data will be encrypted in transit.

### Certificate Generation

#### For Termux (16-001)

```bash
#!/bin/bash
# generate-cert.sh
# Generate a self-signed certificate for the Android file server

DIR="${1:-$HOME/android-server}"
DAYS="${2:-365}"
KEY_SIZE="${3:-2048}"

mkdir -p "$DIR"

# Generate private key
openssl genrsa -out "$DIR/server.key" $KEY_SIZE

# Generate self-signed certificate
openssl req -new -x509 \
    -key "$DIR/server.key" \
    -out "$DIR/server.crt" \
    -days $DAYS \
    -subj "/CN=Android File Server/O=Local/C=US" \
    -addext "subjectAltName=IP:192.168.0.1,IP:192.168.1.1,IP:10.0.0.1,DNS:localhost"

# Set permissions
chmod 600 "$DIR/server.key"
chmod 644 "$DIR/server.crt"

echo "Certificate generated:"
echo "  Key:  $DIR/server.key"
echo "  Cert: $DIR/server.crt"
echo "  Valid for: $DAYS days"

# Show fingerprint for verification
echo ""
echo "Certificate fingerprint (SHA256):"
openssl x509 -in "$DIR/server.crt" -noout -fingerprint -sha256
```

#### For Native Android (16-002)

```kotlin
// SSLUtils.kt
object SSLUtils {

    private const val KEY_ALIAS = "android_file_server"
    private const val KEY_SIZE = 2048
    private const val VALIDITY_DAYS = 365

    fun createSSLContext(context: Context): SSLServerSocketFactory {
        val keyStore = getOrCreateKeyStore(context)

        val keyManagerFactory = KeyManagerFactory.getInstance(
            KeyManagerFactory.getDefaultAlgorithm()
        )
        keyManagerFactory.init(keyStore, charArrayOf())

        val sslContext = SSLContext.getInstance("TLS")
        sslContext.init(keyManagerFactory.keyManagers, null, null)

        return sslContext.serverSocketFactory
    }

    private fun getOrCreateKeyStore(context: Context): KeyStore {
        val keyStoreFile = File(context.filesDir, "keystore.p12")

        if (keyStoreFile.exists()) {
            return loadKeyStore(keyStoreFile)
        }

        return generateKeyStore(keyStoreFile)
    }

    private fun generateKeyStore(file: File): KeyStore {
        // Generate key pair
        val keyPairGenerator = KeyPairGenerator.getInstance("RSA")
        keyPairGenerator.initialize(KEY_SIZE)
        val keyPair = keyPairGenerator.generateKeyPair()

        // Generate self-signed certificate
        val now = Date()
        val notAfter = Date(now.time + VALIDITY_DAYS * 24 * 60 * 60 * 1000L)

        val issuer = X500Name("CN=Android File Server, O=Local, C=US")

        val certBuilder = JcaX509v3CertificateBuilder(
            issuer,
            BigInteger.valueOf(System.currentTimeMillis()),
            now,
            notAfter,
            issuer,
            keyPair.public
        )

        // Add Subject Alternative Names
        val sanBuilder = GeneralNamesBuilder()
        sanBuilder.addName(GeneralName(GeneralName.iPAddress, "192.168.0.1"))
        sanBuilder.addName(GeneralName(GeneralName.iPAddress, "10.0.0.1"))
        sanBuilder.addName(GeneralName(GeneralName.dNSName, "localhost"))

        certBuilder.addExtension(
            Extension.subjectAlternativeName,
            false,
            sanBuilder.build()
        )

        val signer = JcaContentSignerBuilder("SHA256withRSA").build(keyPair.private)
        val cert = JcaX509CertificateConverter().getCertificate(certBuilder.build(signer))

        // Create KeyStore
        val keyStore = KeyStore.getInstance("PKCS12")
        keyStore.load(null, null)
        keyStore.setKeyEntry(
            KEY_ALIAS,
            keyPair.private,
            charArrayOf(),
            arrayOf(cert)
        )

        // Save to file
        FileOutputStream(file).use { fos ->
            keyStore.store(fos, charArrayOf())
        }

        return keyStore
    }

    fun getCertificateFingerprint(context: Context): String {
        val keyStore = getOrCreateKeyStore(context)
        val cert = keyStore.getCertificate(KEY_ALIAS) as X509Certificate

        val md = MessageDigest.getInstance("SHA-256")
        val digest = md.digest(cert.encoded)

        return digest.joinToString(":") { "%02X".format(it) }
    }
}
```

### SSL/TLS Server Configuration

#### Lua (using luasec)

```lua
-- {{{ local function create_ssl_server
local function create_ssl_server(config)
    local socket = require("socket")
    local ssl = require("ssl")

    local ssl_params = {
        mode = "server",
        protocol = "any",  -- Let client negotiate
        key = config.key,
        certificate = config.cert,
        verify = "none",   -- Don't verify client certs
        options = {
            "all",         -- Enable all workarounds
            "no_sslv2",    -- Disable insecure protocols
            "no_sslv3"
        }
    }

    local server = assert(socket.bind(config.bind, config.port))
    server:settimeout(10)

    return {
        server = server,
        ssl_params = ssl_params,

        accept = function(self)
            local client, err = self.server:accept()
            if not client then
                return nil, err
            end

            local ssl_client = ssl.wrap(client, self.ssl_params)
            local success, err = ssl_client:dohandshake()

            if not success then
                client:close()
                return nil, "SSL handshake failed: " .. tostring(err)
            end

            return ssl_client
        end
    }
end
-- }}}
```

#### NanoHTTPD (Java/Kotlin)

```kotlin
// In FileServer.kt
class FileServer(port: Int, private val fileIndex: FileIndex, context: Context) : NanoHTTPD(port) {

    init {
        // Enable HTTPS with self-signed certificate
        val sslFactory = SSLUtils.createSSLContext(context)
        makeSecure(sslFactory, null)
    }

    // ... rest of implementation
}
```

### Browser Behavior

When accessing `https://192.168.0.42:8443/`:

1. **Chrome/Firefox**: Shows "Your connection is not private" / "Warning: Potential Security Risk Ahead"
2. **User action**: Click "Advanced" → "Proceed to site (unsafe)"
3. **After accepting**: Site works normally, padlock shows warning

### Certificate Display in App

```
+----------------------------------------+
|  Certificate Information               |
+----------------------------------------+
|                                        |
|  Status: Active                        |
|  Issued: 2026-02-20                    |
|  Expires: 2027-02-20                   |
|                                        |
|  Fingerprint (SHA256):                 |
|  A1:B2:C3:D4:E5:F6:G7:H8:I9:J0:...    |
|                                        |
|  [ Copy Fingerprint ]  [ Regenerate ]  |
|                                        |
+----------------------------------------+
```

### Fingerprint Verification

Users can manually verify the certificate by comparing fingerprints:

```lua
-- Display fingerprint for verification
-- {{{ local function display_fingerprint
local function display_fingerprint(cert_path)
    local handle = io.popen(string.format(
        'openssl x509 -in "%s" -noout -fingerprint -sha256 | cut -d= -f2',
        cert_path
    ))
    local fingerprint = handle:read("*l")
    handle:close()

    print("Certificate SHA256 Fingerprint:")
    print(fingerprint)
    print("")
    print("Verify this matches what your browser shows when connecting.")
end
-- }}}
```

### Certificate Renewal

Certificates should be regenerated periodically:

```lua
-- {{{ local function check_certificate_expiry
local function check_certificate_expiry(cert_path, warn_days)
    warn_days = warn_days or 30

    local handle = io.popen(string.format(
        'openssl x509 -in "%s" -noout -enddate | cut -d= -f2',
        cert_path
    ))
    local end_date_str = handle:read("*l")
    handle:close()

    -- Parse and check if within warning period
    local end_date = parse_openssl_date(end_date_str)
    local days_remaining = (end_date - os.time()) / (24 * 60 * 60)

    if days_remaining < 0 then
        return "expired", days_remaining
    elseif days_remaining < warn_days then
        return "expiring_soon", days_remaining
    else
        return "valid", days_remaining
    end
end
-- }}}
```

## Suggested Implementation Steps

1. **Create certificate generation script**
   - Termux/bash version
   - Lua wrapper for automation

2. **Implement SSL server wrapper**
   - Lua: Use luasec with proper options
   - Kotlin: Use SSLUtils with KeyStore

3. **Add certificate display**
   - Show fingerprint in CLI/GUI
   - Copy fingerprint functionality

4. **Add certificate management**
   - Check expiry on startup
   - Warn user when expiring
   - One-click regeneration

5. **Document verification process**
   - How to check fingerprint in browser
   - How to accept self-signed cert

## Security Considerations

| Concern | Mitigation |
|---------|------------|
| Self-signed = no CA verification | Use fingerprint verification |
| Certificate in app storage | Use Android Keystore (native) |
| Key compromise | Easy regeneration |
| Man-in-the-middle on first connect | Display fingerprint for out-of-band verification |

## Testing Checklist

- [ ] Certificate generates successfully
- [ ] Server starts with SSL enabled
- [ ] Browser shows security warning (expected)
- [ ] After accepting, connection works
- [ ] Fingerprint matches between server and browser
- [ ] Certificate expiry detection works
- [ ] Regeneration creates new cert

## Related Documents

- 16-001: Android File Server — Vision
- 16-001: Termux + Lua server implementation
- 16-002: Native Android app implementation
- 16-005: Trust warning intermediate page

## Metadata

- **Status**: Open
- **Created**: 2026-02-20
- **Phase**: 16 (Network Media)
- **Estimated Complexity**: Medium
- **Dependencies**: OpenSSL (Termux), BouncyCastle (Android)
