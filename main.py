import torch
from pathlib import Path
import cv2
from data_processor import load_session, get_frame_at_time, extract_audio_segment
from models import (
    vision_model,
    vision_processor,
    audio_model,
    audio_processor,
    mamba,
    projection,
    lm_head,
    tts_model,
    tokenizer,
    DEVICE,
)
from scoring import score_segment, score_full_video

training_folder = Path("training_data")

for zip_file in sorted(training_folder.glob("*chaild.zip")):
    video_path, targets = load_session(zip_file)
    cap = cv2.VideoCapture(video_path)
    fps = cap.get(cv2.CAP_PROP_FPS)
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    print(f"\n--- Training Session: {zip_file.name} ---")

    predictions = []

    for epoch in range(3):
        cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
        frame_idx = 0

        while frame_idx < total_frames:
            ret, frame = cap.read()
            if not ret:
                break
            current_time = frame_idx / fps

            # --- Vision embedding ---
            vision_inputs = vision_processor(images=frame, return_tensors="pt").to(
                DEVICE
            )
            vision_emb = vision_model.vision_tower(
                vision_inputs.pixel_values
            ).last_hidden_state.mean(dim=1)

            # --- Audio embedding (from video segment) ---
            audio_chunk = (
                torch.tensor(
                    extract_audio_segment(
                        video_path.replace(".mp4", ".wav"),
                        current_time,
                        current_time + 1.0,
                    )
                )
                .float()
                .to(DEVICE)
            )
            audio_inputs = audio_processor(
                audio_chunk, sampling_rate=16000, return_tensors="pt"
            ).to(DEVICE)
            audio_emb = audio_model.encoder(
                audio_inputs.input_features
            ).last_hidden_state.mean(dim=1)

            # --- Fuse into Mamba ---
            fused = torch.cat([vision_emb, audio_emb], dim=-1)
            mamba_input = projection(fused)
            mamba_output = mamba(mamba_input.unsqueeze(1))

            # --- Decode text ---
            logits = lm_head(mamba_output.squeeze(1))
            token_ids = logits.argmax(dim=-1)
            predicted_text = tokenizer.decode(token_ids[0], skip_special_tokens=True)

            # --- Determine active segment ---
            current_segment = next(
                (seg for seg in targets if seg["start"] <= current_time <= seg["stop"]),
                {"text": "SILENCE", "start": current_time, "stop": current_time + 1.0},
            )

            # --- Segment-level reward ---
            current_segment = next(
                (seg for seg in targets if seg["start"] <= current_time <= seg["stop"]),
                {"text": "SILENCE", "start": current_time, "stop": current_time + 1.0},
            )

            is_silence = current_segment["text"].upper() == "SILENCE"
            duration = current_segment["stop"] - current_segment["start"]

            # Compute segment reward using character-level similarity
            segment_reward = score_segment(
                predicted_text, current_segment["text"], is_silence, duration
            )

            # --- Backprop only if reward is positive ---
            if segment_reward > 0:
                loss = -segment_reward * mamba_output.sum()
                loss.backward()

            # Store prediction for full-video scoring later
            predictions.append(
                {
                    "start": current_segment["start"],
                    "stop": current_segment["stop"],
                    "pred_text": predicted_text,
                }
            )

            frame_idx += 1

            print(
                f"Processed t={current_time:.3f}s | said='{predicted_text}' | "
                f"target='{current_segment['text']}' | reward={segment_reward:.2f}"
            )

    # --- Full-video scoring at epoch end ---
    if frame_idx >= total_frames:
        avg_reward, per_segment_rewards = score_full_video(predictions, targets)
        print(f"Epoch {epoch+1} full-video avg reward: {avg_reward:.2f}")
