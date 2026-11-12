# AppLibrary12

An iOS 14-inspired App Library port for iOS 12.

AppLibrary12 brings the App Library experience from iOS 14 to jailbroken iOS 12 devices, integrating directly with SpringBoard.

## Compatibility

| Feature | Support |
|---|---|
| iOS 12.0–12.5.8 | Target |
| iPhone | Yes |
| iPad | Yes |
| Architecture | arm64 |
| Jailbreak | Rootful |
| Package | Debian (.deb) |

## Features

- SpringBoard integration
- Swipe navigation to App Library
- Automatically categorized applications
- Suggestions
- Recently Added
- Application search
- Expandable application categories
- Application launching
- iPhone and iPad adaptive layouts
- iOS 14-inspired animations

## Interface

The interface aims to recreate Apple's original iOS 14 App Library.

### iPhone
- Four-column application layout.
- Compact category groups.
- Full-screen search.

### iPad
- Adaptive application grid.
- Expanded category layouts.
- Responsive spacing.

## Building

This project uses Theos.

Requirements:
- Theos
- iOS 12 SDK
- Git
- GitHub Actions

Build locally:

```bash
make package
```

The GitHub Actions workflow will compile the tweak and produce a Debian package.

## Installation

Once a compatible release is available:

```bash
dpkg -i com.applibrary12.tweak_*.deb
```

Restart SpringBoard after installation.

## Disclaimer

AppLibrary12 is an independent community project inspired by Apple's App Library.

It is not affiliated with or endorsed by Apple.

This project is experimental and is not yet a working App Library replacement.

## License

MIT License.
