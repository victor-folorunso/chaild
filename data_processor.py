import zipfile
import json
from pathlib import Path
import cv2 # pyright: ignore[reportMissingImports]
import numpy as np

def load_session(zip_path, extract_path="temp_session"):
    """Extract zip and load video + targets."""
    with zipfile.ZipFile(zip_path, 'r') as z:
        z.extractall(extract_path)
    video_file = next(Path(extract_path).glob("*.mp4"))
    target_file = next(Path(extract_path).glob("*.json"))
    with open(target_file) as f:
        targets = json.load(f)
    return str(video_file), targets

def get_frame_at_time(cap, target_time, fps):
    """Return the frame at a specific time."""
    frame_idx = int(target_time * fps)
    cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
    ret, frame = cap.read()
    return frame if ret else None