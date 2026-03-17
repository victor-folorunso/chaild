import zipfile
import cv2
import soundfile as sf
import torch
import os
import json
from pathlib import Path

def load_session(zip_path):
    with zipfile.ZipFile(zip_path, 'r') as z:
        z.extractall("temp_session")
    video_path = "temp_session/video.mp4"
    targets_path = "temp_session/targets.json"
    with open(targets_path) as f:
        targets = json.load(f)
    return video_path, targets

def get_frame_at_time(cap, target_time, fps):
    frame_idx = int(target_time * fps)
    cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
    ret, frame = cap.read()
    return frame if ret else None