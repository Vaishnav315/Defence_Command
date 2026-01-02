# Scout App

**Scout** is a specialized mobile field application designed for ground assets (soldiers, reconnaissance units). It serves as the primary data collection node in the Defense Command network, enabling real-time Blue Force Tracking (BFT), tactical reporting, and secure communication.

## 🌟 Key Features

### 1. Secure Authentication
- **Login/Signup**: Dedicated "Clean Blue" authentication flow.
- **Identity**: Users register with a unique Username/Email which doubles as their LiveKit CallSign (e.g., "Alpha-1").
- **Persistence**: Auto-login capabilities using secure storage.

### 2. Blue Force Tracking
- **GPS Broadcasting**: Automatically captures and transmits high-precision GPS coordinates to the **Ground Station**.
- **Throttling Optimization**: To prevent database bloat, updates are only broadcasted if the user has moved at least **5 meters** or if **30 seconds** have elapsed since the last update.
- **Live Tracking**: Real-time position updates via REST API / WebSockets.

### 3. Tactical Reporting (SALUTE)
- **Pin Dropping**: Long-press on the tactical map to mark points of interest.
- **Threat Classification**: Categorize sightings (Enemy Soldier, Tank, Artillery) to feed the central intelligence engine.

### 4. Communications
- **Tactical Chat**: Integrated chat network for real-time text communication with Command.
- **Live Feed**: (Optional) WebRTC-based video streaming to the Command Center via LiveKit.

## 🛠 Tech Stack

- **Framework**: Flutter (Dart)
- **State Management**: `Provider` architecture.
- **Maps**: `flutter_map` with OpenStreetMap tiles.
- **Video/Audio**: `livekit_client` for real-time WebRTC streams.
- **Location**: `geolocator` for background/foreground location updates.
- **Notifications**: `flutter_local_notifications` for chat alerts.

## 🎨 UI & UX

- **Theme**: Light "Clean" Aesthetic with Rounded inputs and Staggered Animations.
- **Icons**: Adaptive App Icons (Blue background) supporting Android/iOS standards.
- **Animations**: Entrance animations using `flutter_animate` and custom `AnimationController`.

## 📂 Project Structure

```
lib/
├── main.dart           # Entry point & App Configuration
├── pages/
│   ├── login_page.dart # Auth: Login Screen
│   ├── signup_page.dart# Auth: Registration Screen
│   ├── home_page.dart  # Main Tactical Map & Chat
├── services/
│   ├── api_service.dart# HTTP interaction with Ground Station
│   ├── auth_service.dart# Authentication Logic
│   └── websocket_service.dart # Real-time socket connections
├── providers/
│   └── auth_provider.dart # Centralized session state and user identity management.
└── assets/
    └── images/         # App Icons and Assets
```

## 🚀 Getting Started

1.  **Prerequisites**:
    - Flutter SDK (3.x+)
    - Android/iOS Device or Simulator with GPS capability.

2.  **Configuration**:
    - Ensure `assets/images/icon.png` is present.
    - Check `pubspec.yaml` for dependency versions.

3.  **Run Application**:
    ```bash
    flutter pub get
    flutter run
    ```
    *Note: Use `--release` for performance testing.*

## 📡 Data Protocols

- **Auth**: `POST /auth/login` & `POST /auth/signup` for secure session establishment.
- **Location BFT**: `POST /tactical/location` with `{lat, lng, scout_id, type}` for Blue Force Tracking.
- **Spot Reports**: `POST /tactical/pin` with threat metadata, callsign, and GPS coordinates.
- **Mission Sync**: `GET /mission/history` to retrieve operational records and logs.
