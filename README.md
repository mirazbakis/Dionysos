<p align="center"><img src="docs/assets/logo.png" width="160" alt="Dionysos logo"></p>

# Dionysos

<p align="center"><b>Made by <a href="https://github.com/mirazbakis">Miraz Bakis (@mirazbakis)</a></b></p>

<p align="center">
  <a href="https://github.com/mirazbakis/Dionysos/releases/tag/nightly"><img src="https://img.shields.io/badge/download-nightly-2F7BF6?style=for-the-badge" alt="Download nightly"></a>
  <a href="LICENSE.md"><img src="https://img.shields.io/badge/license-Dionysos%20License-0E1A33?style=for-the-badge" alt="License"></a>
  <a href="https://github.com/mirazbakis"><img src="https://img.shields.io/badge/author-Miraz%20Bakis-5B9BFF?style=for-the-badge&logo=github" alt="Author: Miraz Bakis"></a>
</p>

An on-device iOS signer for **your own Apple IDs**. Import an IPA, pick which of your accounts signs it, and Dionysos signs and installs it straight onto your iPhone. No computer needed.

## Features

- **Several Apple IDs, one tap to switch.** Save your main account and any spare accounts you created yourself, set a default, and choose the account per app. Refreshes reuse the account that signed the app.
- **Account management.** For each Apple ID: its team, development certificates (revoke), App IDs (delete, with the weekly limit shown), registered devices, and the apps it signed on this iPhone.
- **IPA library.** Imported IPAs stay in the app so you can sign them again with any of your accounts.
- **On-device install.** Uses this iPhone's pairing file and LocalDevVPN, the way a computer would.
- **Expiry reminders.** A notification the day before a free-account app expires.
- **Anisette servers.** A built-in list, refreshed from SideStore's community list, plus custom servers.
- **Dark navy, Liquid Glass UI** with blue accents (iOS 26+).

## ⚠️ Only use your own Apple IDs

Sign in only with Apple IDs that belong to you. Never use someone else's account, a shared or bought account, or one you don't have permission to use. Dionysos asks you to confirm this before the first sign-in.

## Building

CI (`.github/workflows/build.yml`) builds an unsigned IPA on every push:

1. `bash ./build-rust.sh` builds the Rust core (`rust/`) into `DionysosFFI.xcframework`.
2. `xcodegen generate` creates `Dionysos.xcodeproj` from `project.yml`.
3. `xcodebuild` builds the app; the workflow ad-hoc signs and zips it.

## Author

<a href="https://github.com/mirazbakis"><img src="https://github.com/mirazbakis.png?size=120" width="72" align="left" alt="Miraz Bakis" style="border-radius:50%"></a>

**Miraz Bakis ([@mirazbakis](https://github.com/mirazbakis))** designed and built Dionysos: the app, its multi-account signing and account management, the navy Liquid Glass interface and the grape-vine logo. Miraz Bakis also made [AltLoad](https://github.com/mirazbakis/AltLoad), the on-device installer Dionysos grew out of.

If you share Dionysos or build something on it, please credit Miraz Bakis and link back here. The [license](LICENSE.md) requires it.

<br clear="left">

## Acknowledgments

Built on Miraz Bakis's [AltLoad](https://github.com/mirazbakis/AltLoad), plus [isideload](https://github.com/nab138/isideload), [idevice](https://github.com/jkcoxson/idevice), [StikPair](https://github.com/StephenDev0/StikPair) and [LocalDevVPN](https://github.com/jkcoxson/LocalDevVPN), with anisette servers from [SideStore](https://github.com/SideStore). Inspired by AltStore, Feather and Ksign. See the in-app Acknowledgments page and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License

Dionysos is © 2026 Miraz Bakis (@mirazbakis) under the [Dionysos License](LICENSE.md): free for personal, non-commercial use and sharing, with credit to Miraz Bakis. Third-party parts keep their own licenses ([THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)).

Dionysos isn't affiliated with Apple or any of the projects above.
