"""
Simulation Engine

This script spawns multiple AI agents (soldiers, tanks, UAVs) that connect to the LiveKit room.
They stream a loop video and publish live GPS coordinates to simulate a dynamic battlefield.
"""
import asyncio
import cv2
import numpy as np
import json
import time
import os
import random
from livekit import api, rtc

# --- CONFIGURATION ---
LIVEKIT_URL = "wss://myworkspace-m3kejsmr.livekit.cloud"
LIVEKIT_API_KEY = "APISaJfUrD2fzMy"
LIVEKIT_API_SECRET = "Fyjitvmr7EfqRmF0reohx38YZzpCmxB42iXpbnL1taA"
ROOM_NAME = "war-room"
VIDEO_DIR = "Videos" # Directory containing video files

# --- SPEED CONTROL ---
# Coordinate delta per frame (approximate conversion for simulation speed)
SPEED_BASE = 0.0002
TARGET_FPS = 15 # Cap at 15 FPS for stability
FRAME_DELAY = 1.0 / TARGET_FPS

# --- ENTITY GENERATION ---
ENTITY_TYPES = ["soldier", "tank", "truck", "uav"]
NUM_ENTITIES = 8
BASE_LAT = 17.4200
BASE_LONG = 78.4700

# OPTIMIZATION: Target Resolution
TARGET_WIDTH = 320
TARGET_HEIGHT = 240

def get_video_files():
    """Returns a list of video files from the VIDEO_DIR."""
    if not os.path.exists(VIDEO_DIR):
        print(f"⚠️ Warning: Video directory '{VIDEO_DIR}' not found.")
        return []
    
    files = [os.path.join(VIDEO_DIR, f) for f in os.listdir(VIDEO_DIR) 
             if f.lower().endswith(('.mp4', '.avi', '.mov', '.mkv'))]
    return files

def generate_squad():
    squad = []
    video_files = get_video_files()
    
    if not video_files:
        print("❌ No video files found! Entities will not stream video.")
    
    for i in range(NUM_ENTITIES):
        etype = random.choice(ENTITY_TYPES)
        # Random ID
        eid = f"{etype.capitalize()}-{random.randint(10, 99)}"
        # Random Start Position (Scatter approx 1km)
        lat = BASE_LAT + random.uniform(-0.01, 0.01)
        lng = BASE_LONG + random.uniform(-0.01, 0.01)
        # Random Direction Vector
        dx = random.uniform(-1, 1)
        dy = random.uniform(-1, 1)
        
        # Assign a random video file
        video_path = random.choice(video_files) if video_files else None
        
        squad.append({
            "id": eid,
            "type": etype,
            "lat": lat,
            "long": lng,
            "dir": (dx, dy),
            "video_path": video_path
        })
    return squad

class FakeEntity:
    def __init__(self, config):
        self.id = config["id"]
        self.type = config["type"]
        self.lat = config["lat"]
        self.long = config["long"]
        self.dir_lat = config["dir"][0]
        self.dir_long = config["dir"][1]
        self.video_path = config["video_path"]
        self.room = None
        self.source = None
        self.track = None
        self.cap = None 

    async def connect(self):
        print(f"🤖 Connecting {self.id} ({self.type})...")
        self.room = rtc.Room()
        token = api.AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET) \
            .with_identity(self.id) \
            .with_name(self.id) \
            .with_grants(api.VideoGrants(room_join=True, room=ROOM_NAME, can_publish=True)) \
            .to_jwt()
        
        await self.room.connect(LIVEKIT_URL, token)
        
        # Create Video Track (Optimized Resolution)
        self.source = rtc.VideoSource(TARGET_HEIGHT, TARGET_WIDTH)
        self.track = rtc.LocalVideoTrack.create_video_track("camera", self.source)
        options = rtc.TrackPublishOptions(
            source=rtc.TrackSource.SOURCE_CAMERA,
            simulcast=False, # Disable simulcast to save bandwidth
            video_codec=rtc.VideoCodec.H264,
        )
        await self.room.local_participant.publish_track(self.track, options)
        
        # Initialize Video Capture
        if self.video_path:
            self.cap = cv2.VideoCapture(self.video_path)
            # print(f"   🎥 Loaded video: {os.path.basename(self.video_path)}")
        
        print(f"✅ {self.id} Online!")

    async def read_and_send_frame(self):
        if not self.cap or not self.source:
            return

        ret, frame = self.cap.read()
        if not ret:
            # Loop video
            self.cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
            ret, frame = self.cap.read()
            if not ret: return 
        
        try:
            # OPTIMIZATION: Resize BEFORE color conversion
            frame_resized = cv2.resize(frame, (TARGET_WIDTH, TARGET_HEIGHT))
            
            # Simple check for Green/Purple (YUV/RGB mismatch usually)
            # LiveKit expects RGBA buffer
            frame_rgb = cv2.cvtColor(frame_resized, cv2.COLOR_BGR2RGBA)
            
            lk_frame = rtc.VideoFrame(TARGET_WIDTH, TARGET_HEIGHT, rtc.VideoBufferType.RGBA, frame_rgb.tobytes())
            self.source.capture_frame(lk_frame)
        except Exception as e:
            # print(f"Frame error {self.id}: {e}")
            pass

    async def send_gps(self):
        speed_mod = 1.0
        if self.type == "uav": speed_mod = 2.0
        if self.type == "solider": speed_mod = 0.5
        
        self.lat  += (SPEED_BASE * speed_mod) * self.dir_lat
        self.long += (SPEED_BASE * speed_mod) * self.dir_long

        if abs(self.lat - BASE_LAT) > 0.03: self.dir_lat *= -1
        if abs(self.long - BASE_LONG) > 0.03: self.dir_long *= -1

        gps_data = json.dumps({
            "id": self.id,
            "type": self.type, 
            "lat": self.lat,
            "long": self.long
        })
        
        await self.room.local_participant.publish_data(
            payload=gps_data.encode('utf-8'),
            reliable=True,
            topic="gps"
        )
        return ""

    async def disconnect(self):
        if self.cap:
            self.cap.release()
        await self.room.disconnect()

async def run_simulation():
    squad_config = generate_squad()
    bots = [FakeEntity(cfg) for cfg in squad_config]
    
    await asyncio.gather(*(bot.connect() for bot in bots))
    
    print(f"🚀 SQUAD DEPLOYED ({len(bots)} Units) @ {TARGET_FPS} FPS / {TARGET_WIDTH}x{TARGET_HEIGHT}p")
    frame_count = 0

    try:
        while True:
            start_time = time.time()
            
            # Update Video & GPS
            # Run concurrently for speed
            await asyncio.gather(*(bot.read_and_send_frame() for bot in bots))
            await asyncio.gather(*(bot.send_gps() for bot in bots))
            
            frame_count += 1
            if frame_count % TARGET_FPS == 0:
                print(f"--- 📡 STATUS [{time.strftime('%H:%M:%S')}] ---")
            
            # Smart FPS Cap
            elapsed = time.time() - start_time
            sleep_time = max(0, FRAME_DELAY - elapsed)
            await asyncio.sleep(sleep_time)

    except KeyboardInterrupt:
        print("\n🛑 Retreating Squad...")
    finally:
        await asyncio.gather(*(bot.disconnect() for bot in bots))

if __name__ == "__main__":
    asyncio.run(run_simulation())