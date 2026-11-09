# Broom: Mobile App

The Flutter app. Items and photos stay on the phone. If you add a Claude API key, it can suggest item names from photos.

## Requirements

- Flutter 3.47.7 (Dart 3.13.5)
- Xcode 27.2, with an iOS simulator
- CocoaPods

## Setup

```bash
make setup
```

## Run

```bash
make run
```

Uses the iPhone 16 Pro simulator. For another one: `make run DEVICE="iPhone 16"`.

## Deploy

**Live at:** https://apps.apple.com/in/app/broom-minimalist-declutter/id6761337910

**Where it runs:** App Store, bundle id `com.kohjakob.broom`.

**Needs:** Apple Developer team `4TDG4JP93N` and App Store Connect access.

Raise `version` in `pubspec.yaml`, then:

```bash
flutter build ipa
```

Upload `build/ios/ipa/*.ipa` with the Transporter app, then submit the build in App Store Connect. Store text is in `../Docs/publish/`, which isn't in git.

## Configuration

The Claude API key is optional. It's entered in the app's settings.
