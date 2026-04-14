# Arr Client

[![Flutter CI](https://github.com/Nicktronix/arr-client/actions/workflows/ci.yml/badge.svg)](https://github.com/Nicktronix/arr-client/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/Nicktronix/arr-client/branch/main/graph/badge.svg)](https://codecov.io/gh/Nicktronix/arr-client)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.38.5-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Linux%20%7C%20Windows%20%7C%20macOS%20%7C%20Web-brightgreen)]()

A mobile client for [Sonarr](https://sonarr.tv/) and [Radarr](https://radarr.video/) media servers built with Flutter. Manage your media library on the go with a native Material Design 3 interface.

> **Note**: This is an independent third-party client and is not affiliated with Sonarr or Radarr projects.

## ✨ Features

- 📺 **Sonarr**: Browse, search, and add TV series • Episode detail view with comprehensive file info • Toggle monitoring • Delete episode files • Interactive release search
- 🎬 **Radarr**: Browse, search, and add movies • Enhanced movie details with custom formats • Toggle monitoring • Delete movie files • Manual movie searches
- 📥 **Downloads**: Unified queue for both services • Real-time progress tracking • Detailed release browser
- 🔄 **Multi-Instance**: Manage multiple Sonarr/Radarr servers • Easy switching • Secure credential storage
- 🔒 **Security**: Biometric authentication • Encrypted backups • Platform keychain/keystore integration
- 🎨 **Material Design 3**: Modern, responsive UI • Pull-to-refresh • Optimized for mobile

## 🚀 Quick Start

### Download Pre-Built APK

**For Android users**: Download the latest APK from [Releases](https://github.com/Nicktronix/arr-client/releases) - no Flutter SDK required!

### Build from Source

**Prerequisites**: [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.38.5 or higher

1. **Clone the repository**
   ```bash
   git clone https://github.com/Nicktronix/arr-client.git
   cd arr-client
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   # Android
   flutter run -d android
   
   # iOS (requires macOS with Xcode)
   flutter run -d ios
   ```

### First-Time Setup

1. Launch the app (you'll see an empty state)
2. Tap the **settings icon** (⚙️) in the top-right
3. Add your Sonarr/Radarr instance(s):
   - **Name**: e.g., "Home Sonarr"
   - **URL**: Your instance URL (e.g., `https://sonarr.example.com`)
   - **API Key**: Found in Sonarr/Radarr → Settings → General → Security
   - **Optional**: Enable Basic Auth if using a proxy
4. Select the active instance with the radio button
5. Return to home screen and start browsing!

## 🏗️ Architecture

Built with a custom centralized state management pattern:
- **AppStateManager**: Single source of truth for active instances
- **CacheManager**: 5-minute memory cache with stale-while-revalidate
- **CachedDataLoader**: Mixin pattern for consistent loading states
- **Instance-aware caching**: Isolated cache per instance for performance

See [`CLAUDE.md`](CLAUDE.md) for detailed architecture documentation.

## 🛠️ Troubleshooting

**Empty screens on first launch?**
- This is expected! Tap the settings icon (⚙️) to add your first instance.

**"Unauthorized" error?**
- Check your API key in Sonarr/Radarr → Settings → General → Security

**"Not found" error?**
- Verify your base URL (should be `https://sonarr.example.com`, not `/api/v3`)

**Can't connect?**
- Test the URL in your browser first
- Check firewall/network settings
- Ensure you can reach the server from your device

## 🔒 Security

- **Credential Storage**: API keys stored in platform keychain/keystore (hardware-encrypted)
- **Biometric Lock**: Optional Face ID/Touch ID/fingerprint authentication
- **Encrypted Backups**: AES-256-GCM with 600k PBKDF2 iterations (OWASP 2023 compliant)
- **Network**: HTTPS support with certificate validation
- **Zero vulnerabilities**: Comprehensive security audit completed (Dec 2025)

See [SECURITY.md](SECURITY.md) for responsible disclosure policy.

## 🤝 Contributing

Contributions are welcome! Please check out our [Contributing Guidelines](CONTRIBUTING.md) and [Code of Conduct](CODE_OF_CONDUCT.md).

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## ⭐ Show Your Support

If you find this project useful:
- ⭐ Star this repository
- 🐛 Report bugs and suggest features in [Issues](https://github.com/Nicktronix/arr-client/issues)
- 🔀 Contribute code improvements
- 📢 Share with others in the homelab community

## 🙏 Acknowledgments

Built with [Flutter](https://flutter.dev/) • Inspired by [Sonarr](https://sonarr.tv/) and [Radarr](https://radarr.video/)
