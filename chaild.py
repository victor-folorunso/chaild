"""
chAIld — chaild.py
================================================================
The single entry point for everything.

Four modes:

  TRAIN SIMULATED   python chaild.py train
    Feed .chaild.zip sessions from training_data/.
    She watches, predicts, scores herself, learns.
    Weights, affect, and ledger saved after every epoch.
    This is the primary training mode.

  TRAIN REAL        python chaild.py train --real
    Live camera + microphone input. No JSON targets.
    A human trainer is present in real time — they speak,
    gesture, react. chAIld watches and listens through the
    camera and mic and responds through the speaker.
    Reward comes from the trainer scoring her responses
    via keyboard (1-9) in real time.
    This is the physical world mode. No zip files needed.

  USE               python chaild.py use
    Live camera + microphone. No learning — weights frozen.
    She perceives the world and responds as she is.
    Use this to observe how far she has come.
    No backprop. No weight updates. No ledger changes.
    Her affect state still runs — she still feels.
    Affect is saved at the end of a use session so her
    emotional state after interaction carries forward.

  STATUS            python chaild.py status
    Print current memory state: weights loaded, affect state,
    full ledger summary. No models loaded. Fast.

================================================================
Usage:
  python chaild.py train             # simulated training
  python chaild.py train --real      # real-world training
  python chaild.py use               # observe / interact
  python chaild.py status            # inspect memory
  python chaild.py train --reset     # wipe weights, keep affect+ledger
  python chaild.py train --wipe      # wipe everything, full fresh start
================================================================
"""

import argparse
import sys
import json
from pathlib import Path


# =============================================================================
# Argument parsing
# =============================================================================

def parse_args():
    parser = argparse.ArgumentParser(
        prog="chaild",
        description="chAIld — entry point",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "mode",
        choices=["train", "use", "status"],
        help="Mode to run",
    )
    parser.add_argument(
        "--real",
        action="store_true",
        help="(train mode only) Use live camera+mic instead of .chaild.zip files",
    )
    parser.add_argument(
        "--reset",
        action="store_true",
        help="(train mode only) Wipe weights.pt before starting. Keeps affect + ledger.",
    )
    parser.add_argument(
        "--wipe",
        action="store_true",
        help="Wipe ALL memory (weights, affect, ledger). Full fresh start.",
    )
    return parser.parse_args()


# =============================================================================
# Status — fast, no models loaded
# =============================================================================

def run_status():
    from config import MASTERY_THRESHOLD
    memory_dir   = Path("memory")
    weights_path = memory_dir / "weights.pt"
    affect_path  = memory_dir / "affect.json"
    ledger_path  = memory_dir / "ledger.json"

    print("\n" + "=" * 60)
    print("  chAIld — memory status")
    print("=" * 60)

    # Weights
    if weights_path.exists():
        import torch
        try:
            ckpt = torch.load(weights_path, map_location="cpu", weights_only=True)
            meta = ckpt.get("shape_meta", {})
            print(f"\n  🧠 Weights:   {weights_path}")
            print(f"     Shape metadata: {meta}")
        except Exception as e:
            print(f"\n  ⚠  Weights file exists but could not be read: {e}")
    else:
        print(f"\n  🌱 Weights:   not found (fresh start)")

    # Affect
    if affect_path.exists():
        try:
            with open(affect_path) as f:
                affect_data = json.load(f)
            somatic = affect_data.get("somatic", {})
            core    = affect_data.get("core", [])
            print(f"\n  💛 Affect:    {affect_path}")
            print(f"     Somatic : {somatic}")
            print(f"     Core    : {len(core)}-dim vector (showing first 4): {core[:4]}")
        except Exception as e:
            print(f"\n  ⚠  Affect file exists but could not be read: {e}")
    else:
        print(f"\n  💛 Affect:    not found (neutral start)")

    # Ledger
    if ledger_path.exists():
        try:
            with open(ledger_path) as f:
                ledger = json.load(f)
            print(f"\n  📖 Ledger:    {ledger_path} — {len(ledger)} session(s)")
            print(f"\n  {'─' * 72}")
            print(f"  {'SESSION':<35} {'SEEN':>4}  {'BEST':>6}  {'LAST':>6}  STATUS")
            print(f"  {'─' * 72}")
            for name, data in sorted(ledger.items()):
                status = "✅ mastered" if data["best_reward"] >= MASTERY_THRESHOLD else "🔄 learning"
                print(
                    f"  {name:<35} {data['times_trained']:>4}  "
                    f"{data['best_reward']:>6.2f}  {data['last_reward']:>6.2f}  {status}"
                )
            print(f"  {'─' * 72}")
        except Exception as e:
            print(f"\n  ⚠  Ledger file exists but could not be read: {e}")
    else:
        print(f"\n  📖 Ledger:    not found (no sessions yet)")

    print()


# =============================================================================
# Wipe helpers
# =============================================================================

def handle_wipe_flags(args):
    """Process --reset and --wipe before loading any models."""
    memory_dir   = Path("memory")
    weights_path = memory_dir / "weights.pt"
    affect_path  = memory_dir / "affect.json"
    ledger_path  = memory_dir / "ledger.json"

    if args.wipe:
        confirm = input(
            "\n  ⚠  --wipe will delete ALL memory: weights, affect, AND ledger.\n"
            "     This cannot be undone. She will start as a blank slate.\n"
            "     Type 'wipe' to confirm, anything else to cancel: "
        ).strip().lower()
        if confirm == "wipe":
            for p in [weights_path, affect_path, ledger_path]:
                if p.exists():
                    p.unlink()
                    print(f"  🗑  Deleted {p}")
            print("  ✓  Full wipe complete. Starting fresh.\n")
        else:
            print("  Cancelled.\n")
            sys.exit(0)

    elif args.reset:
        confirm = input(
            "\n  ⚠  --reset will delete weights.pt only.\n"
            "     Affect state and ledger are preserved.\n"
            "     She will forget what she learned but keep how she felt.\n"
            "     Type 'reset' to confirm, anything else to cancel: "
        ).strip().lower()
        if confirm == "reset":
            if weights_path.exists():
                weights_path.unlink()
                print(f"  🗑  Deleted {weights_path}")
            print("  ✓  Weights reset. Affect and ledger intact.\n")
        else:
            print("  Cancelled.\n")
            sys.exit(0)


# =============================================================================
# Shared model + memory bootstrap
# =============================================================================

def bootstrap(learn: bool = True):
    """
    Load models, optimizer, affect state, and memory.
    Returns (optimizer, affect, ledger).

    learn=True  → optimizer is active (training modes)
    learn=False → optimizer is a dummy (use mode — no backprop)
    """
    import torch
    from models import projection, mamba, lm_head
    from affect import AffectState
    from memory import load_memory

    affect = AffectState()

    if learn:
        from config import LEARNING_RATE
        optimizer = torch.optim.AdamW(
            list(projection.parameters()) +
            list(mamba.parameters()) +
            list(lm_head.parameters()),
            lr=LEARNING_RATE,
        )
    else:
        # Dummy optimizer — exists so load_memory signature is satisfied
        # but will never be stepped
        optimizer = torch.optim.AdamW(
            list(projection.parameters()) +
            list(mamba.parameters()) +
            list(lm_head.parameters()),
            lr=1e-4,
        )

    ledger = load_memory(projection, mamba, lm_head, optimizer, affect)

    if not learn:
        # Freeze all trainable layers in use mode
        for p in list(projection.parameters()) + list(mamba.parameters()) + list(lm_head.parameters()):
            p.requires_grad_(False)

    return optimizer, affect, ledger


# =============================================================================
# TRAIN — SIMULATED
# =============================================================================

def run_train_simulated():
    """
    Core training loop. Reads .chaild.zip sessions from training_data/.
    Learns from every session, saves after every epoch.
    """
    # Import here so model loading only happens in the right modes
    import torch
    import cv2
    import numpy as np
    from config import (
        DEVICE, TORCH_DTYPE, EPOCHS, REWARD_THRESHOLD,
        SILENCE_LABEL, TRAINING_FOLDER, TEMP_EXTRACT_PATH, MAX_REWARD,
    )
    from models import (
        vision_model, vision_processor, audio_model, audio_processor,
        mamba, projection, lm_head, tts_model, tokenizer,
    )
    from data_processor import load_session
    from scoring import score_segment, score_full_video, worst_segments
    from affect import extract_observed_affect
    from memory import save_memory, ledger_record_epoch, ledger_should_skip, ledger_summary

    optimizer, affect, ledger = bootstrap(learn=True)

    print("\n" + "=" * 60)
    print("  chAIld — simulated training")
    print("=" * 60)
    ledger_summary(ledger)

    training_folder = Path(TRAINING_FOLDER)
    session_files   = sorted(training_folder.glob("*.chaild.zip"))

    if not session_files:
        print("  No .chaild.zip sessions found in training_data/.")
        print("  Add sessions and run again.\n")
        return

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

        for epoch in range(EPOCHS):
            cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
            frame_idx   = 0
            predictions = []

            print(f"\n  Epoch {epoch + 1}/{EPOCHS}")
            print(f"  {'-' * 40}")

            while frame_idx < total_frames:
                ret, frame = cap.read()
                if not ret:
                    break

                current_time = frame_idx / fps

                # Vision
                vision_inputs = vision_processor(images=frame, return_tensors="pt").to(DEVICE)
                with torch.no_grad():
                    vision_emb = vision_model.vision_tower(
                        vision_inputs.pixel_values
                    ).last_hidden_state.mean(dim=1)

                # Audio (fallback silent — wire real audio via soundfile if available)
                audio_data   = np.zeros(16000, dtype=np.float32)
                audio_inputs = audio_processor(audio_data, sampling_rate=16000, return_tensors="pt").to(DEVICE)
                with torch.no_grad():
                    audio_emb = audio_model.encoder(
                        audio_inputs.input_features.to(TORCH_DTYPE)
                    ).last_hidden_state.mean(dim=1)

                # Affect
                affect_vec   = affect.to_input_tensor()
                fused        = torch.cat([vision_emb, audio_emb, affect_vec], dim=-1)
                mamba_input  = projection(fused)
                mamba_output = mamba(mamba_input.unsqueeze(1))
                logits       = lm_head(mamba_output.squeeze(1))
                token_ids    = logits.argmax(dim=-1)
                predicted_text = tokenizer.decode(token_ids[0].unsqueeze(0), skip_special_tokens=True)

                # Target
                current_segment = next(
                    (seg for seg in targets if seg["start"] <= current_time <= seg["stop"]),
                    {"text": SILENCE_LABEL, "start": current_time, "stop": current_time + (1.0 / fps)},
                )
                is_silence      = current_segment["text"].upper() == SILENCE_LABEL
                duration        = current_segment["stop"] - current_segment["start"]
                observed_affect = extract_observed_affect(current_segment)

                # Affect contagion
                if is_silence:
                    affect.felt_silence(observed_affect)
                elif observed_affect:
                    affect.absorb_observed(observed_affect)

                # Score
                affect_mult    = affect.reward_multiplier()
                segment_reward = score_segment(
                    predicted_text, current_segment["text"],
                    is_silence, duration,
                    affect_multiplier=affect_mult, max_reward=MAX_REWARD,
                )

                # Reward → affect
                affect.absorb_reward(segment_reward, MAX_REWARD)

                # Backprop
                optimizer.zero_grad()
                loss = (
                    -torch.tensor(segment_reward, dtype=TORCH_DTYPE, device=DEVICE)
                    * mamba_output.sum()
                )
                loss.backward()
                torch.nn.utils.clip_grad_norm_(
                    list(projection.parameters()) + list(mamba.parameters()) + list(lm_head.parameters()),
                    max_norm=1.0,
                )
                optimizer.step()
                affect.decay()

                # Speak
                if predicted_text.strip() and not is_silence:
                    if np.random.random() >= affect.silence_threshold():
                        try:
                            tts_model.synthesize(predicted_text, **affect.tts_params())
                        except Exception:
                            pass

                predictions.append({
                    "start": current_segment["start"],
                    "stop":  current_segment["stop"],
                    "pred_text": predicted_text,
                })

                silence_marker = " 🤫" if is_silence else ""
                print(
                    f"  t={current_time:7.3f}s | pred='{predicted_text[:20]}' | "
                    f"target='{current_segment['text'][:20]}'{silence_marker} | "
                    f"reward={segment_reward:.2f} | ax={affect_mult:.2f} | {affect.summary()}"
                )
                frame_idx += 1

            avg_reward, per_segment_rewards = score_full_video(predictions, targets)
            pct = (avg_reward / MAX_REWARD) * 100

            print(f"\n  ── Epoch {epoch + 1} summary ──")
            print(f"     Avg reward : {avg_reward:.2f} / {MAX_REWARD:.2f}  ({pct:.1f}%)")
            print(f"     {affect.summary()}")

            if avg_reward < REWARD_THRESHOLD:
                weak = worst_segments(targets, per_segment_rewards, n=3)
                print(f"     ⚠  Weakest segments:")
                for s in weak:
                    print(f"       [{s['start']:.2f}s → {s['stop']:.2f}s]  '{s['text']}'")
            else:
                print(f"     ✓  Above threshold.")

            ledger_record_epoch(ledger, session_name, epoch + 1, avg_reward, per_segment_rewards, affect.to_dict())
            save_memory(projection, mamba, lm_head, optimizer, affect, ledger)

            if pct >= 99.0:
                print(f"     🎓 Near-perfect. Stopping early.")
                break

        cap.release()
        print(f"\n  Session '{session_name}' complete.")

    print("\n" + "=" * 60)
    print("  chAIld — simulated training complete.")
    print("=" * 60)
    ledger_summary(ledger)


# =============================================================================
# TRAIN — REAL (live camera + mic, human trainer scores in real time)
# =============================================================================

def run_train_real():
    """
    Real-world training mode.
    Camera + microphone provide the sensory stream.
    A human trainer observes and scores her responses in real time (1–9).
    No JSON targets. No zip files. Just presence.
    """
    import torch
    import cv2
    import numpy as np
    import sounddevice as sd  # pip install sounddevice
    from config import (
        DEVICE, TORCH_DTYPE, LEARNING_RATE, MAX_REWARD,
        SILENCE_LABEL, SAMPLE_RATE,
    )
    from models import (
        vision_model, vision_processor, audio_model, audio_processor,
        mamba, projection, lm_head, tts_model, tokenizer,
    )
    from memory import save_memory

    optimizer, affect, ledger = bootstrap(learn=True)

    print("\n" + "=" * 60)
    print("  chAIld — REAL training mode")
    print("  Camera and microphone active.")
    print("  Score her responses: press 1–9, then Enter.")
    print("  Press Ctrl+C to end the session.")
    print("=" * 60)
    print(f"  Feeling : {affect.summary()}\n")

    cap = cv2.VideoCapture(0)  # default camera
    if not cap.isOpened():
        print("  ⚠  Could not open camera. Check your device.")
        return

    fps           = cap.get(cv2.CAP_PROP_FPS) or 30.0
    frame_idx     = 0
    session_name  = "real_training"

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                break

            current_time = frame_idx / fps

            # Vision
            vision_inputs = vision_processor(images=frame, return_tensors="pt").to(DEVICE)
            with torch.no_grad():
                vision_emb = vision_model.vision_tower(
                    vision_inputs.pixel_values
                ).last_hidden_state.mean(dim=1)

            # Audio — live mic capture (1 second window)
            try:
                audio_data = sd.rec(
                    int(SAMPLE_RATE), samplerate=SAMPLE_RATE,
                    channels=1, dtype="float32", blocking=True
                ).flatten()
            except Exception:
                audio_data = np.zeros(SAMPLE_RATE, dtype=np.float32)

            audio_inputs = audio_processor(audio_data, sampling_rate=SAMPLE_RATE, return_tensors="pt").to(DEVICE)
            with torch.no_grad():
                audio_emb = audio_model.encoder(
                    audio_inputs.input_features.to(TORCH_DTYPE)
                ).last_hidden_state.mean(dim=1)

            # Affect + forward pass
            affect_vec   = affect.to_input_tensor()
            fused        = torch.cat([vision_emb, audio_emb, affect_vec], dim=-1)
            mamba_input  = projection(fused)
            mamba_output = mamba(mamba_input.unsqueeze(1))
            logits       = lm_head(mamba_output.squeeze(1))
            token_ids    = logits.argmax(dim=-1)
            predicted_text = tokenizer.decode(token_ids[0].unsqueeze(0), skip_special_tokens=True)

            # Speak (if she has something to say)
            if predicted_text.strip():
                if np.random.random() >= affect.silence_threshold():
                    try:
                        tts_model.synthesize(predicted_text, **affect.tts_params())
                    except Exception:
                        pass

            print(f"\n  t={current_time:.2f}s | said: '{predicted_text}'")
            print(f"  {affect.summary()}")

            # Human trainer scores the response
            try:
                raw = input("  Score (1–9, or Enter to skip, 's' for silence): ").strip().lower()
                if raw == "s":
                    # Trainer marks this as a silence moment
                    segment_reward = MAX_REWARD if not predicted_text.strip() else 0.0
                elif raw.isdigit() and 1 <= int(raw) <= 9:
                    segment_reward = float(raw)
                else:
                    # No score given — skip backprop, still update affect
                    affect.decay()
                    frame_idx += 1
                    continue
            except KeyboardInterrupt:
                break

            # Affect contagion from reward
            affect.absorb_reward(segment_reward, MAX_REWARD)

            # Backprop
            affect_mult = affect.reward_multiplier()
            optimizer.zero_grad()
            loss = (
                -torch.tensor(segment_reward * affect_mult, dtype=TORCH_DTYPE, device=DEVICE)
                * mamba_output.sum()
            )
            loss.backward()
            torch.nn.utils.clip_grad_norm_(
                list(projection.parameters()) + list(mamba.parameters()) + list(lm_head.parameters()),
                max_norm=1.0,
            )
            optimizer.step()
            affect.decay()

            frame_idx += 1

    except KeyboardInterrupt:
        pass

    cap.release()
    print("\n  Session ended. Saving memory...")

    # Record real session to ledger loosely
    if session_name not in ledger:
        ledger[session_name] = {"times_trained": 0, "best_reward": 0.0, "last_reward": 0.0, "history": []}
    ledger[session_name]["times_trained"] += 1

    save_memory(projection, mamba, lm_head, optimizer, affect, ledger)
    print("  💾 Memory saved.")
    print(f"  Final feeling: {affect.summary()}\n")


# =============================================================================
# USE — observe / interact, no learning
# =============================================================================

def run_use():
    """
    Use mode — she perceives and responds. No learning.
    Camera + microphone active. Weights frozen.
    Affect still runs — she still feels.
    Affect state is saved at the end so interaction leaves a mark.
    """
    import torch
    import cv2
    import numpy as np
    import sounddevice as sd
    from config import DEVICE, TORCH_DTYPE, SAMPLE_RATE
    from models import (
        vision_model, vision_processor, audio_model, audio_processor,
        mamba, projection, lm_head, tts_model, tokenizer,
    )
    from affect import extract_observed_affect
    from memory import MEMORY_DIR, AFFECT_PATH, LEDGER_PATH
    import json

    _, affect, ledger = bootstrap(learn=False)

    print("\n" + "=" * 60)
    print("  chAIld — use mode  (weights frozen, no learning)")
    print("  She is watching and listening.")
    print("  Press Ctrl+C to end.")
    print("=" * 60)
    print(f"  Feeling : {affect.summary()}\n")

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        print("  ⚠  Could not open camera.")
        return

    fps       = cap.get(cv2.CAP_PROP_FPS) or 30.0
    frame_idx = 0

    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                break

            current_time = frame_idx / fps

            vision_inputs = vision_processor(images=frame, return_tensors="pt").to(DEVICE)
            with torch.no_grad():
                vision_emb = vision_model.vision_tower(
                    vision_inputs.pixel_values
                ).last_hidden_state.mean(dim=1)

            try:
                audio_data = sd.rec(
                    int(SAMPLE_RATE), samplerate=SAMPLE_RATE,
                    channels=1, dtype="float32", blocking=True
                ).flatten()
            except Exception:
                audio_data = np.zeros(SAMPLE_RATE, dtype=np.float32)

            audio_inputs = audio_processor(audio_data, sampling_rate=SAMPLE_RATE, return_tensors="pt").to(DEVICE)
            with torch.no_grad():
                audio_emb = audio_model.encoder(
                    audio_inputs.input_features.to(TORCH_DTYPE)
                ).last_hidden_state.mean(dim=1)

            affect_vec = affect.to_input_tensor()

            with torch.no_grad():
                fused        = torch.cat([vision_emb, audio_emb, affect_vec], dim=-1)
                mamba_input  = projection(fused)
                mamba_output = mamba(mamba_input.unsqueeze(1))
                logits       = lm_head(mamba_output.squeeze(1))
                token_ids    = logits.argmax(dim=-1)
                predicted_text = tokenizer.decode(token_ids[0].unsqueeze(0), skip_special_tokens=True)

            if predicted_text.strip():
                if np.random.random() >= affect.silence_threshold():
                    try:
                        tts_model.synthesize(predicted_text, **affect.tts_params())
                    except Exception:
                        pass

            print(f"  t={current_time:.2f}s | '{predicted_text}' | {affect.summary()}")

            # Affect still runs in use mode — she feels the interaction
            affect.felt_silence({}) if not predicted_text.strip() else affect.decay()

            frame_idx += 1

    except KeyboardInterrupt:
        pass

    cap.release()

    # Save affect state — use sessions leave emotional marks
    MEMORY_DIR.mkdir(parents=True, exist_ok=True)
    tmp = AFFECT_PATH.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(affect.to_dict(), f, indent=2)
    tmp.replace(AFFECT_PATH)

    print(f"\n  Session ended.")
    print(f"  Feeling : {affect.summary()}")
    print(f"  💛 Affect saved.\n")


# =============================================================================
# Entry point
# =============================================================================

if __name__ == "__main__":
    args = parse_args()

    # Status needs no models — run before anything else
    if args.mode == "status":
        run_status()
        sys.exit(0)

    # Handle wipe/reset flags before loading models
    if args.mode == "train":
        handle_wipe_flags(args)

    # Dispatch
    if args.mode == "train":
        if args.real:
            run_train_real()
        else:
            run_train_simulated()
    elif args.mode == "use":
        run_use()
