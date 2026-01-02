# Defense Command App

**Defense Command** is the central tactical situational awareness application for field commanders. It aggregates data from all deployed assets to provide a comprehensive Common Operating Picture (COP), integrating live unit tracking, video intelligence, and environmental analysis.

## 🌟 Key Features

### 1. Tactical Command Dashboard
- **Login/Signup**: Secure "Dark Shield" authentication system.
- **Maps**: Multi-layer tactical map powered by `flutter_map`.
    - **Styles**: Satellite, Dark Mode, Outdoor, and Light styles.
    - **Overlays**: Weather data (Temperature, Precipitation), Heatmaps.
- **Entity Tracking**: Real-time visualization of all assets:
    - **Blue Force**: Soldiers, UAVs (Drones).
    - **Red Force**: Detected Enemies (Tanks, Artillery, Hostiles).

### 2. Live Intelligence Suite
- **Video Feeds**: Grid view of live WebRTC video streams from deployed UAVs and Body Cams (via LiveKit).
- **Signal Analysis**: Real-time reception of "Spot Reports" from Scout units.

### 3. Communications & Control
- **Encrypted Chat**: Direct messaging channel with individual units or broadcast groups.
- **Mission Planning**: Visual pathfinding and threat range estimation.
- **Mission History**: Comprehensive logs of past operations with GPS playback.
- **Simulation Sandbox**: Dedicated environment for testing tactical scenarios without field assets.

## 🛠 Tech Stack

- **Framework**: Flutter (Dart)
- **State Management**: `Provider` + `StatefulWidget` optimization.
- **Maps**: `flutter_map`, `latlong2`.
- **Real-time Video**: `livekit_client` (WebRTC).
- **Networking**: `http` (REST), WebSocket.

## 🎨 UI & UX

- **Theme**: Dark Tactical Aesthetic with "Glassmorphism" elements.
- **Icons**: Adaptive App Icons (Dark Grey background) for seamless home screen integration.
- **Animations**: Staggered list animations and smooth map transitions.

## 📂 Project Structure

```
lib/
├── main.dart               # Entry point, theme configuration, and global provider setup.
├── home_page.dart          # Main Tactical Dashboard (Map, Bottom Sheet Intel).
├── simulation_screen.dart  # Sandbox environment for synthetic data testing.
├── more_page.dart          # Quick actions, analytics, and mission history access.
├── settings_page.dart      # Application preferences and connection settings.
├── soldiers_page.dart      # Detailed directory of active infantry units.
├── uavs_page.dart          # Streaming grid for active drone assets.
├── fullscreen_video_view.dart # Immersive high-detail video intelligence viewer.
├── pages/
│   ├── login_page.dart     # Commander authentication.
│   └── signup_page.dart    # Commander enrollment.
├── services/
│   ├── api_service.dart    # Centralized REST communication.
│   ├── auth_service.dart   # JWT and session management.
│   └── livekit_service.dart# Real-time WebRTC orchestration.
├── providers/
│   └── entity_provider.dart# Unified state for tracked battlefield assets.
├── theme/
│   └── tactical_theme.dart # Dark Shield design system definitions.
├── utils/
│   ├── map_layers_helper.dart # Dynamic map layer and overlay logic.
│   └── markers.dart        # Tactical iconography and pin definitions.
└── images/                 # Cryptographic logos and tactical assets.
```

## 🚀 Getting Started

1.  **Prerequisites**:
    - Flutter SDK (3.x+)
    - Backend "Ground Station" running (for map tiles and auth).

2.  **Configuration**:
    - Update `api_service.dart` with your Ground Station IP.
    - Run `flutter pub get` to install dependencies.

3.  **Run Application**:
    ```bash
    flutter run
    ```

## 📡 Data Flow

1.  **Authentication**: Users authenticate to receive a session token.
2.  **Polling**: The app polls `/state` for entity updates and `/tactical/pins` for markers.
3.  **Streaming**: Connects to LiveKit Room "Mission-Control" to subscribe to tactical feeds.
