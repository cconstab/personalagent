# App Icon Generation

This directory contains the source SVG icon and scripts to generate platform-specific app icons.

## Icon Design

The app icon features a **purple padlock** symbolizing:
- 🔒 **Privacy** - Private AI agent with end-to-end encryption
- 💜 **atPlatform** - Purple is the atPlatform brand color
- 🛡️ **Security** - Your data stays on your device and atPlatform

## Quick Start

### Generate all icons:

```bash
cd app
chmod +x generate_icons.sh install_icons.sh
./generate_icons.sh
./install_icons.sh
```

### Manual process:

1. **Edit the design** (optional):
   ```bash
   # Open in your preferred SVG editor
   open assets/icon/app_icon.svg
   ```

2. **Generate platform icons**:
   ```bash
   ./generate_icons.sh
   ```
   This creates icons in `assets/icon/generated/` for all platforms.

3. **Install to platform folders**:
   ```bash
   ./install_icons.sh
   ```
   This copies the generated icons to their respective platform directories.

4. **Clean and rebuild**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## Requirements

- **ImageMagick** - For converting SVG to PNG
  ```bash
  brew install imagemagick
  ```

## Generated Sizes

### macOS
- 1024x1024, 512x512, 256x256, 128x128, 64x64, 32x32, 16x16

### iOS
- 1024x1024 (App Store)
- 180x180, 167x167, 152x152, 120x120, 87x87, 80x80, 76x76
- 60x60, 58x58, 40x40, 29x29, 20x20

### Android
- xxxhdpi: 192x192
- xxhdpi: 144x144
- xhdpi: 96x96
- hdpi: 72x72
- mdpi: 48x48

### Windows
- 256x256, 128x128, 64x64, 48x48, 32x32, 16x16

### Linux
- 512x512, 256x256, 128x128, 64x64, 48x48, 32x32

## Files

- `app_icon.svg` - Source SVG (1024x1024)
- `generate_icons.sh` - Generate all platform icons
- `install_icons.sh` - Copy icons to platform directories
- `generated/` - Output directory for all generated icons

## Customization

To customize the icon:

1. Edit `assets/icon/app_icon.svg` in your preferred SVG editor
2. Keep the 1024x1024 viewBox for best results
3. Use vector shapes for crisp scaling
4. Regenerate icons with `./generate_icons.sh`

## Platform-Specific Notes

### macOS
Icons are in `macos/Runner/Assets.xcassets/AppIcon.appiconset/`

### iOS
Create the directory structure if it doesn't exist:
```bash
mkdir -p ios/Runner/Assets.xcassets/AppIcon.appiconset
```

### Android
Adaptive icons use foreground + background layers. The script generates both.

### Windows
Icon is stored as `windows/runner/resources/app_icon.png`

### Linux
Icon is stored as `linux/app_icon.png`
