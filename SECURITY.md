# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

If you discover a security vulnerability in Arr Client, please report it privately:

### How to Report

1. **Email**: Send details to the repository owner (check GitHub profile for contact)
2. **GitHub Security Advisory**: Use the "Security" tab → "Report a vulnerability"

### What to Include

Please provide as much information as possible:

- Type of vulnerability (e.g., credential exposure, XSS, authentication bypass)
- Affected version(s)
- Steps to reproduce the issue
- Potential impact
- Suggested fix (if you have one)
- Your contact information for follow-up

### Response Timeline

- **Initial Response**: Within 48 hours acknowledging receipt
- **Status Update**: Within 7 days with assessment and planned timeline
- **Resolution**: Depends on severity and complexity

### What to Expect

1. We'll investigate and validate the report
2. We'll develop a fix if needed
3. We'll coordinate disclosure timing with you
4. We'll credit you in the security advisory (unless you prefer anonymity)

## Security Best Practices for Users

### Credential Management

- ✅ **Use HTTPS** for all remote Sonarr/Radarr instances
- ✅ **Rotate API keys** periodically from Sonarr/Radarr settings
- ✅ **Use strong passwords** for backup encryption (12+ characters)
- ✅ **Test locally first** before adding remote instances
- ✅ **Delete unused instances** to remove credentials from device

### Network Security

- ⚠️ **Avoid HTTP** for remote instances (only use for localhost)
- ⚠️ **Public networks**: Use VPN when accessing remote instances
- ⚠️ **Port forwarding**: Prefer VPN over direct internet exposure
- ✅ **Basic Auth**: Enable on reverse proxy for additional protection

### Device Security

- ✅ **Enable biometric lock** in app settings
- ✅ **Keep device secure** with PIN/password/biometric lock
- ✅ **Regular updates**: Update app when new versions are released
- ✅ **Backup carefully**: Store encrypted backups securely

### What the App Does to Protect You

**Credential Storage**:
- iOS: Keychain with first-unlock accessibility
- Android: Encrypted SharedPreferences with Keystore
- Desktop: Platform-specific secure storage (Keychain/DPAPI/libsecret)
- Web: Web Cryptography API

**Encryption Standards**:
- AES-256-GCM for backup encryption
- PBKDF2 with 600,000 iterations for key derivation
- Cryptographically random salts (128-bit)
- NIST-compliant encryption algorithms

**Data Sanitization**:
- Automatic URL credential redaction in error messages
- API key removal from logs
- Bearer/Basic token sanitization
- No sensitive data in crash reports

**Network Security**:
- HTTPS warnings for remote HTTP URLs
- SSL/TLS certificate validation
- API keys in headers (never URL parameters)
- 30-second timeout to prevent hanging connections

## Known Security Considerations

### API Keys Have Full Access

Sonarr/Radarr API keys provide **full administrative access** to your media server. This app requires that level of access to function.

**What this means**:
- App can read, modify, and delete all content
- App can change server settings
- App can trigger downloads and searches
- Compromised device = compromised server access

**Mitigation**:
- Use device lock (PIN/password/biometric)
- Enable app biometric lock
- Delete instances when selling/giving away device
- Regularly review and rotate API keys

### Local Network Assumptions

This app is designed for **personal homelab use** where:
- You trust your local network
- Sonarr/Radarr are on your private network
- Remote access is through VPN, not direct internet exposure

**Not recommended for**:
- Shared devices with untrusted users
- Enterprise/multi-tenant environments
- Public Wi-Fi without VPN
- Direct internet-exposed servers

### Backup Encryption

Encrypted backups are **only as strong as your password**:
- 12+ character passwords recommended
- Mix uppercase, lowercase, numbers, symbols
- Don't reuse passwords from other services
- Lost password = lost backup (no recovery)

## Dependency Security

This project uses:
- `flutter_secure_storage` for credential management
- `encrypt` + `pointycastle` for backup encryption
- `local_auth` for biometric authentication

**Vulnerability Scanning**:
- Run `flutter pub outdated` regularly
- Monitor GitHub Dependabot alerts
- Update dependencies with `flutter pub upgrade`

## Security Updates

Security fixes are prioritized:
- **Critical**: Patched within 24-48 hours
- **High**: Patched within 1 week
- **Medium**: Patched in next minor release
- **Low**: Patched in next release cycle

## Disclosure Policy

- Vulnerabilities are fixed before public disclosure
- Security advisories published via GitHub Security
- Credits given to reporters (unless they prefer anonymity)
- Coordinated disclosure with affected parties

## Questions?

For security-related questions (not vulnerabilities), open a [Discussion](https://github.com/Nicktronix/arr-client/discussions) or contact the maintainer.

---

**Last Updated**: December 2024
