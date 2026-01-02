from ultralytics import YOLO

# 1. Load your trained drone model
model = YOLO('drone_model.pt')

# 2. Configure the tracking
video_path = 'videos/video_3.mp4' 

# 3. Run the tracker
# - source: the video file
# - conf: confidence threshold (0.5 means 50%)
# - iou: intersection over union (helps avoid duplicate boxes)
# - show: opens a window to watch it live
# - save: saves the result to runs/detect/track
# - tracker: "bytetrack.yaml" is the standard algorithm for tracking
results = model.track(source=video_path, conf=0.5, iou=0.5, exist_ok=True, show=True, save=True, tracker="bytetrack.yaml")

print("Tracking finished! Check the 'runs/detect' folder for the video.")