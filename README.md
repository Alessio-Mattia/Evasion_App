# Evasion2026

<div align="center">

![Evasion2026 Banner](https://img.shields.io/badge/Evasion2026-Social%20Discovery%20App-6C63FF?style=for-the-badge)

**Discover and share experiences around you — in real time.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%2B%20Auth-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Google Maps](https://img.shields.io/badge/Google%20Maps-SDK-4285F4?logo=googlemaps&logoColor=white)](https://pub.dev/packages/google_maps_flutter)
[![License](https://img.shields.io/badge/license-MIT-brightgreen)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-lightgrey?logo=apple)](https://flutter.dev/multi-platform)

</div>

---

## What is Evasion2026?

**Evasion2026** is a location-based social app built with Flutter and Firebase. Users can discover nearby events, posts, and experiences shared by others around them — with a real-time map interface and smooth geolocation.

Originally prototyped in FlutterFlow, the project was fully migrated to native Dart/Flutter for complete architectural control, performance, and extensibility.

---

## Features

- 📍 **Real-time geolocation** — live user position with background tracking (Transistor Software SDK)
- 🗺️ **Interactive map** — nearby posts displayed on Google Maps, fetched from Firestore `user_locations`
- 📸 **Post creation** — share experiences with photos, text, and location
- 🔒 **Firebase Authentication** — secure sign-in with email/password
- 🔔 **Live updates** — Firestore real-time listeners for instant feed refresh
- 📱 **Cross-platform** — iOS (TestFlight) and Android ready

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI Framework | Flutter 3.x / Dart |
| Backend & Database | Firebase Firestore |
| Authentication | Firebase Auth |
| Storage | Firebase Storage |
| Maps | Google Maps Flutter SDK |
| Geolocation | flutter_background_geolocation (Transistor) |
| State Management | Provider / setState |
| Version Control | Git + GitHub (feature branch workflow) |

---

## Project Structure

```
lib/
├── main.dart
├── screens/
│   ├── home_screen.dart
│   ├── map_screen.dart
│   ├── post_screen.dart
│   └── profile_screen.dart
├── widgets/
│   ├── post_card.dart
│   └── map_marker.dart
├── services/
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   └── location_service.dart
└── models/
    ├── post_model.dart
    └── user_model.dart
```

---

## Getting Started

### Prerequisites

- Flutter SDK `>=3.0.0`
- Dart SDK `>=3.0.0`
- A Firebase project with Firestore, Auth and Storage enabled
- Google Maps API key

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/Evasion2026.git
cd Evasion2026

# 2. Install dependencies
flutter pub get

# 3. Add your Firebase config files
#    → android/app/google-services.json
#    → ios/Runner/GoogleService-Info.plist

# 4. Add your Google Maps key
#    → android/app/src/main/AndroidManifest.xml
#    → ios/Runner/AppDelegate.swift

# 5. Generate the code and create the local env files
flutter gen-l10n
dart run build_runner build
cp env/example.json env/dev.json
cp env/example.json env/prod.json

# 6. Run the app (--flavor is required, the build fails without it)
flutter run --flavor dev -t lib/main_dev.dart --dart-define-from-file=env/dev.json
flutter run --flavor prod -t lib/main_prod.dart --dart-define-from-file=env/prod.json
```

> **Note:** Firebase config files and API keys are not included in this repository for security reasons. See the Firebase console to generate them.

---

## Development Workflow

This project uses a **feature branch workflow**:

```
main          ← stable, production-ready
  └── develop ← integration branch
        ├── feat/map-view
        ├── feat/auth-flow
        └── feat/post-creation
```

- All new features are developed on `feat/` branches
- Pull Requests go into `develop`, reviewed before merging
- `main` is only updated for stable releases

---

## Roadmap

- [ ] Stories / ephemeral posts (24h)
- [ ] Push notifications (FCM)
- [ ] In-app messaging between users
- [ ] Geohash-based feed filtering (radius)
- [ ] App Store & Play Store release

---

## Authors

| Name | Role | GitHub |
|---|---|---|
| Sirio | Lead developer — architecture, maps, geolocation | [@your_handle](https://github.com/your_handle) |
| Alessio | Lead Developer — auth, UI components, Firebase | [@frere_handle](https://github.com/frere_handle) |

---

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<div align="center">
  <sub>Built with Flutter · Firebase · ☕</sub>
</div>
