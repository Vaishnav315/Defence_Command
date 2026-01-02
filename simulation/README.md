# Battlefield Simulation Engine

The **Simulation Engine** is a testing utility designed to populate the Defense Command network with synthetic data. It spawns multiple autonomous agents (bots) that simulate soldiers, vehicles, and UAVs on the battlefield.

## 🎯 Purpose

- **Load Testing**: Verifies the Ground Station's ability to handle multiple incoming video streams and high-frequency GPS updates.
- **Scenario Training**: Provides a dynamic environment for testing the "Defense Command" app's tactical map without needing physical assets in the field.
- **Protocol Verification**: Ensures the LiveKit video and data channel protocols are functioning correctly.

## 🤖 Features

- **Multi-Agent Simulation**: Spawns a squad of diverse units (Soldiers, Tanks, Trucks, UAVs).
- **Video Injection**: Streams a looping video file (`test_video.mp4`) as the camera feed for each bot.
- **Dynamic Movement**: Agents move realistically around a base coordinate with randomized vectors and boundary checks.
- **Real-time Telemetry**: Broadcasts GPS coordinates via LiveKit Data Channels at ~30Hz.

## 🛠 Usage

1.  **Prerequisites**:
    - Python 3.9+
    - `opencv-python`
    - `livekit`
    - `numpy`

2.  **Configuration**:
    - Ensure `test_video.mp4` is present in the directory.
    - Verify LiveKit credentials in `fake_solider.py` (or move them to environment variables for security).

3.  **Run Simulation**:
    ```bash
    python fake_solider.py
    ```

4.  **Observation**:
    - The script will print the status of connected bots (UUID, callsing, and role).
    - Open the **Defense Command App** (Simulation Screen) or **Ground Station** map to see the units moving in real-time.
    - Check the `Videos/` directory for synthetic reconnaissance footage used by the agents.

## 📂 Project Structure

```
simulation/
├── fake_solider.py      # Main simulation script for spawning autonomous agents.
├── README.md            # Documentation and usage guide.
└── Videos/              # Directory containing synthetic video feeds for agents.
    └── test_video.mp4   # Default looping video for camera injection.
```

## ⚠️ Notes

- The simulation uses a hardcoded base location (Lat: 17.4200, Lng: 78.4700). Modify `BASE_LAT` and `BASE_LONG` in the script to change the operation theater.
- Ensure the LiveKit server is reachable; otherwise, bots will fail to connect.
