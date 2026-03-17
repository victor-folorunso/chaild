"""
chAIld — main training loop
================================================================
Architecture:
    MP4 → vision_model (frozen) → vision_emb
    MP4 → audio_model  (frozen) → audio_emb
    affect_state.core           → affect_vec   ← emotion
    [vision_emb ‖ audio_emb ‖ affect_vec] → projection → Mamba → lm_head → text → TTS

Training signal:
    JSON targets define what she should say and how the scene felt.
    Text gap → reward. Reward + observed affect → felt state update.
    Felt state feeds back into every subsequent forward pass.

Silence is not nothing:
    During silence segments, emotional contagion still runs through
    the felt_silence() pathway — distinct from speech contagion because
    silence tends to concentrate emotion. Unannotated silence drifts
    her gently toward calm. Annotated silence (awe, dread, peace)
    imprints at heightened weight. She feels silence as itself.

    Additionally, her pain/valence state creates a stochastic
    silence_threshold — when she is in distress she is more likely
    to stay quiet even when she has something to say. Not suppression.
    Expression.

Memory:
    Weights, optimizer, affect state, and ledger saved after every epoch.
    chAIld never forgets what she learned or how it made her feel.
================================================================
"""

import torch
import cv2
import numpy as np
from pathlib import Path

from config import (
    DEVICE,
    TORCH_DTYPE,
    EPOCHS,
    LEARNING_RATE,
    REWARD_THRESHOLD,
    SILENCE_LABEL,
    TRAINING_FOLDER,
    TEMP_EXTRACT_PATH,
    MAX_REWARD,
)
from data_processor import load_session
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
)
from scoring import score_segment, score_full_video, worst_segments
from affect import AffectState, extract_observed_affect
from memory import (
    save_memory,
    load_memory,
    ledger_record_epoch,
    ledger_should_skip,
    ledger_summary,
)

# =============================================================================
# Optimizer — trainable layers only
# =============================================================================
optimizer = torch.optim.AdamW(
    list(projection.parameters()) +
    list(mamba.parameters()) +
    list(lm_head.parameters()),
    lr=LEARNING_RATE,
)

# =============================================================================
# Affect — chAIld's persistent emotional state
# =============================================================================
affect = AffectState()

# =============================================================================
# Wake up — restore everything from last run
# =============================================================================
print("\n" + "=" * 60)
print("  chAIld — waking up")
print("=" * 60)

ledger = load_memory(projection, mamba, lm_head, optimizer, affect)
ledger_summary(ledger)

# =============================================================================
# Session loop
# =============================================================================
training_folder = Path(TRAINING_FOLDER)
session_files   = sorted(training_folder.glob("*.chaild.zip"))

if not session_files:
    print("No .chaild.zip sessions found in training_data/. Nothing to do.")
    exit(0)

for zip_file in session_files:
    session_name = zip_file.name

    print(f"\n{'=' * 60}")
    print(f"  Session : {session_name}")
    print(f"  Feeling : {affect.summary()}")
    print(f"{'=' * 60}")

    if ledger_should_skip(ledger, session_name):
        continue

    try:
        video_path, targets = load_session(zip_file, extract_path=TEMP_EXTRACT_PATH)
    except FileNotFoundError as e:
        print(f"  [SKIP] {e}")
        continue

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"  [SKIP] Could not open video: {video_path}")
        continue

    fps          = cap.get(cv2.CAP_PROP_FPS) or 30.0
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

    # =========================================================================
    # Epoch loop
    # =========================================================================
    for epoch in range(EPOCHS):
        cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
        frame_idx   = 0
        predictions = []

        print(f"\n  Epoch {epoch + 1}/{EPOCHS}")
        print(f"  {'-' * 40}")

        # =====================================================================
        # Frame loop
        # =====================================================================
        while frame_idx < total_frames:
            ret, frame = cap.read()
            if not ret:
                break

            current_time = frame_idx / fps

            # -----------------------------------------------------------------
            # 1. Vision — what she sees
            # -----------------------------------------------------------------
            vision_inputs = vision_processor(
                images=frame, return_tensors="pt"
            ).to(DEVICE)

            with torch.no_grad():
                vision_emb = vision_model.vision_tower(
                    vision_inputs.pixel_values
                ).last_hidden_state.mean(dim=1)          # [1, VISION_EMB_DIM]

            # -----------------------------------------------------------------
            # 2. Audio — what she hears
            #    Fallback: silent numpy array.
            #    To use real audio extract a .wav with ffmpeg and load with
            #    soundfile (see TRAINING.md for the ffmpeg command).
            # -----------------------------------------------------------------
            audio_data   = np.zeros(16000, dtype=np.float32)
            audio_inputs = audio_processor(
                audio_data, sampling_rate=16000, return_tensors="pt"
            ).to(DEVICE)

            with torch.no_grad():
                audio_emb = audio_model.encoder(
                    audio_inputs.input_features.to(TORCH_DTYPE)
                ).last_hidden_state.mean(dim=1)          # [1, AUDIO_EMB_DIM]

            # -----------------------------------------------------------------
            # 3. Affect vector — how she feels right now
            #    Her emotional state colours every perception.
            #    Fused with sensory input before entering Mamba.
            # -----------------------------------------------------------------
            affect_vec = affect.to_input_tensor()        # [1, AFFECT_DIM]

            # -----------------------------------------------------------------
            # 4. Fuse → project → Mamba → decode
            # -----------------------------------------------------------------
            fused        = torch.cat([vision_emb, audio_emb, affect_vec], dim=-1)
            mamba_input  = projection(fused)
            mamba_output = mamba(mamba_input.unsqueeze(1))

            logits         = lm_head(mamba_output.squeeze(1))
            token_ids      = logits.argmax(dim=-1)
            predicted_text = tokenizer.decode(
                token_ids[0].unsqueeze(0), skip_special_tokens=True
            )

            # -----------------------------------------------------------------
            # 5. Find active target segment
            # -----------------------------------------------------------------
            current_segment = next(
                (seg for seg in targets
                 if seg["start"] <= current_time <= seg["stop"]),
                {
                    "text":  SILENCE_LABEL,
                    "start": current_time,
                    "stop":  current_time + (1.0 / fps),
                },
            )

            is_silence      = current_segment["text"].upper() == SILENCE_LABEL
            duration        = current_segment["stop"] - current_segment["start"]
            observed_affect = extract_observed_affect(current_segment)

            # -----------------------------------------------------------------
            # 6. Emotional contagion — two distinct pathways
            #
            #    SPEECH segments: absorb_observed()
            #      Standard contagion weight. What she sees while someone
            #      speaks shapes her state in proportion to the moment.
            #
            #    SILENCE segments: felt_silence()
            #      Silence concentrates emotion. Annotated silence absorbs
            #      at 1.3× weight. Unannotated silence drifts toward calm.
            #      She does not pass through silence unchanged.
            # -----------------------------------------------------------------
            if is_silence:
                affect.felt_silence(observed_affect)
            else:
                if observed_affect:
                    affect.absorb_observed(observed_affect)

            # -----------------------------------------------------------------
            # 7. Score — modulated by her current affect state
            # -----------------------------------------------------------------
            affect_mult    = affect.reward_multiplier()
            segment_reward = score_segment(
                predicted_text,
                current_segment["text"],
                is_silence,
                duration,
                affect_multiplier=affect_mult,
                max_reward=MAX_REWARD,
            )

            # -----------------------------------------------------------------
            # 8. Reward shapes her felt state — this is stakes
            #    Success → pleasure, positive valence
            #    Failure → pain, negative valence
            # -----------------------------------------------------------------
            affect.absorb_reward(segment_reward, MAX_REWARD)

            # -----------------------------------------------------------------
            # 9. Backpropagate through trainable layers
            # -----------------------------------------------------------------
            optimizer.zero_grad()
            loss = (
                -torch.tensor(segment_reward, dtype=TORCH_DTYPE, device=DEVICE)
                * mamba_output.sum()
            )
            loss.backward()
            torch.nn.utils.clip_grad_norm_(
                list(projection.parameters()) +
                list(mamba.parameters()) +
                list(lm_head.parameters()),
                max_norm=1.0,
            )
            optimizer.step()

            # -----------------------------------------------------------------
            # 10. Decay affect — moods fade, they don't last forever
            # -----------------------------------------------------------------
            affect.decay()

            # -----------------------------------------------------------------
            # 11. Speak — gated by silence threshold
            #
            #    She only speaks when:
            #      a) She produced non-empty text
            #      b) The target is not SILENCE
            #      c) She clears the stochastic silence threshold
            #         (derived from pain + negative valence)
            #
            #    The threshold is not suppression. It is the natural
            #    tendency of a mind under distress to go quiet —
            #    not because it was told to, but because that is what
            #    pain does to a voice.
            # -----------------------------------------------------------------
            if predicted_text.strip() and not is_silence:
                silence_prob = affect.silence_threshold()
                if np.random.random() >= silence_prob:
                    try:
                        tts_params = affect.tts_params()
                        tts_model.synthesize(predicted_text, **tts_params)
                    except Exception:
                        pass  # TTS failure never blocks training

            # -----------------------------------------------------------------
            # 12. Log
            # -----------------------------------------------------------------
            predictions.append({
                "start":     current_segment["start"],
                "stop":      current_segment["stop"],
                "pred_text": predicted_text,
            })

            silence_marker = " 🤫" if is_silence else ""
            print(
                f"  t={current_time:7.3f}s | "
                f"pred='{predicted_text[:20]}' | "
                f"target='{current_segment['text'][:20]}'{silence_marker} | "
                f"reward={segment_reward:.2f} | "
                f"ax={affect_mult:.2f} | "
                f"{affect.summary()}"
            )

            frame_idx += 1

        # =====================================================================
        # Epoch end — score, record, save
        # =====================================================================
        avg_reward, per_segment_rewards = score_full_video(predictions, targets)
        pct = (avg_reward / MAX_REWARD) * 100

        print(f"\n  ── Epoch {epoch + 1} summary ──────────────────────────")
        print(f"     Avg reward  : {avg_reward:.2f} / {MAX_REWARD:.2f}  ({pct:.1f}%)")
        print(f"     {affect.summary()}")

        if avg_reward < REWARD_THRESHOLD:
            weak = worst_segments(targets, per_segment_rewards, n=3)
            print(f"     ⚠  Below threshold. Weakest segments:")
            for s in weak:
                print(f"       [{s['start']:.2f}s → {s['stop']:.2f}s]  '{s['text']}'")
        else:
            print(f"     ✓  Above threshold.")

        ledger_record_epoch(
            ledger, session_name, epoch + 1,
            avg_reward, per_segment_rewards,
            affect.to_dict(),
        )
        save_memory(projection, mamba, lm_head, optimizer, affect, ledger)

        if pct >= 99.0:
            print(f"     🎓 Near-perfect. Stopping early.")
            break

    cap.release()
    print(f"\n  Session '{session_name}' complete.\n")

# =============================================================================
# Done
# =============================================================================
print("\n" + "=" * 60)
print("  chAIld — training complete.")
print("=" * 60)
ledger_summary(ledger)
