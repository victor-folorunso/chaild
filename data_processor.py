import zipfile
import json
import shutil
from pathlib import Path
import cv2  # pyright: ignore[reportMissingImports]


def load_session(zip_path: str | Path, extract_path: str = "temp_session") -> tuple[str, list]:
    """
    Extract a .chaild.zip session and return the video path + targets.
    Clears the extract directory first to avoid stale files from prior sessions.

    Returns:
        video_path (str): absolute path to the extracted .mp4
        targets (list): list of {"start": float, "stop": float, "text": str}
    """
    extract_path = Path(extract_path)

    # Clear stale session data
    if extract_path.exists():
        shutil.rmtree(extract_path)
    extract_path.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(zip_path, "r") as z:
        z.extractall(extract_path)

    video_file = next(extract_path.rglob("*.mp4"), None)
    target_file = next(extract_path.rglob("*.json"), None)

    if video_file is None:
        raise FileNotFoundError(f"No .mp4 found in {zip_path}")
    if target_file is None:
        raise FileNotFoundError(f"No .json found in {zip_path}")

    with open(target_file, "r", encoding="utf-8") as f:
        targets = json.load(f)

    return str(video_file), targets


def get_frame_at_time(cap: cv2.VideoCapture, target_time: float, fps: float):
    """Return the BGR frame at a specific timestamp. Returns None on failure."""
    frame_idx = int(target_time * fps)
    cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
    ret, frame = cap.read()
    return frame if ret else None
