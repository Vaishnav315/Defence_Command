from ultralytics import YOLO
import cv2

# 1. Load your trained model
# Ensure 'drone_model.pt' is in the same directory or provide the full path
model = YOLO('drone_model.pt') 

# 2. Define the image you want to test
# Replace 'test_image.jpg' with the actual name of your image file
image_path = 'test_image.jpg' 

# 3. Run detection (Inference)
# 'conf=0.5' means it will only show detections with 50% or higher confidence
results = model.predict(source=image_path, save=True, exist_ok=True, conf=0.5)

# 4. Show the results
# The 'results' object is a list (in case you fed multiple images). We take the first one.
for result in results:
    # This will display the image with bounding boxes on your screen
    result.show()  
    
    # Optional: Print how many objects were found
    print(f"Detected {len(result.boxes)} objects.")