# Assets Directory

Place your app assets here:

## Images
- `assets/images/bitcoin_logo.png` - Bitcoin logo
- `assets/images/app_icon.png` - App icon (1024x1024)

## Icons
App icons are configured in:
- Android: `android/app/src/main/res/`
- iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

## Generating Icons

You can use Flutter packages to generate icons:

```yaml
# Add to pubspec.yaml dev_dependencies
flutter_launcher_icons: ^0.13.1

flutter_icons:
  android: true
  ios: true
  image_path: "assets/images/app_icon.png"
  adaptive_icon_background: "#121212"
  adaptive_icon_foreground: "assets/images/app_icon.png"
```

Then run:
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

## Recommended Icon Sizes

### Android
- ldpi: 36x36
- mdpi: 48x48
- hdpi: 72x72
- xhdpi: 96x96
- xxhdpi: 144x144
- xxxhdpi: 192x192

### iOS
- 20x20 (@1x, @2x, @3x)
- 29x29 (@1x, @2x, @3x)
- 40x40 (@1x, @2x, @3x)
- 60x60 (@2x, @3x)
- 76x76 (@1x, @2x)
- 83.5x83.5 (@2x)
- 1024x1024 (App Store)
