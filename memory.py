"""
chAIld — memory.py
================================================================
Persistent memory. The bloodline.

Four things saved after every epoch:
  1. Model weights      — projection, mamba, lm_head
  2. Optimizer state    — AdamW momentum; resumes learning smoothly
  3. Affect state       — somatic layer + core affect vector;
                          her emotional history across all runs
  4. Training ledger    — session history, rewards, emotional arc

memory/
  weights.pt     — model weights + optimizer
  affect.json    — somatic + core affect vector
  ledger.json    — training history per session
================================================================
"""

import torch
import json
from pathlib import Path
from datetime import datetime

from config import MASTERY_THRESHOLD

MEMORY_DIR    = Path("memory")
WEIGHTS_PATH  = MEMORY_DIR / "weights.pt"
AFFECT_PATH   = MEMORY_DIR / "affect.json"
LEDGER_PATH   = MEMORY_DIR / "ledger.json"


# =============================================================================
# Save
# =============================================================================

def save_memory(
    projection,
    mamba,
    lm_head,
    optimizer,
    affect_state,
    ledger: dict,
) -> None:
    """
    Persist everything to disk after every epoch.
    Uses atomic write (tmp → rename) on every file — no corruption risk.
    """
    MEMORY_DIR.mkdir(parents=True, exist_ok=True)

    # --- Weights + optimizer ---
    tmp = WEIGHTS_PATH.with_suffix(".tmp")
    torch.save(
        {
            "projection": projection.state_dict(),
            "mamba":       mamba.state_dict(),
            "lm_head":     lm_head.state_dict(),
            "optimizer":   optimizer.state_dict(),
        },
        tmp,
    )
    tmp.replace(WEIGHTS_PATH)

    # --- Affect state ---
    tmp = AFFECT_PATH.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(affect_state.to_dict(), f, indent=2)
    tmp.replace(AFFECT_PATH)

    # --- Ledger ---
    tmp = LEDGER_PATH.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(ledger, f, indent=2)
    tmp.replace(LEDGER_PATH)

    print(f"  💾 Memory saved → {MEMORY_DIR}/")


# =============================================================================
# Load
# =============================================================================

def load_memory(
    projection,
    mamba,
    lm_head,
    optimizer,
    affect_state,
) -> dict:
    """
    Restore everything from disk on startup.
    Safe on first run — missing files start clean.
    Returns the ledger dict.
    """
    ledger = {}

    # --- Weights + optimizer ---
    if WEIGHTS_PATH.exists():
        try:
            ckpt = torch.load(WEIGHTS_PATH, map_location="cpu", weights_only=True)
            projection.load_state_dict(ckpt["projection"])
            mamba.load_state_dict(ckpt["mamba"])
            lm_head.load_state_dict(ckpt["lm_head"])
            optimizer.load_state_dict(ckpt["optimizer"])
            print(f"  🧠 Weights loaded ← {WEIGHTS_PATH}")
        except Exception as e:
            print(f"  ⚠  Weights load failed ({e}). Starting fresh.")
    else:
        print(f"  🌱 No prior weights. Starting fresh.")

    # --- Affect state ---
    if AFFECT_PATH.exists():
        try:
            with open(AFFECT_PATH, "r", encoding="utf-8") as f:
                affect_state.load_dict(json.load(f))
            print(f"  💛 Affect state loaded ← {AFFECT_PATH}")
            print(f"     {affect_state.summary()}")
        except Exception as e:
            print(f"  ⚠  Affect load failed ({e}). Starting neutral.")
    else:
        print(f"  💛 No prior affect state. Starting neutral.")

    # --- Ledger ---
    if LEDGER_PATH.exists():
        try:
            with open(LEDGER_PATH, "r", encoding="utf-8") as f:
                ledger = json.load(f)
            print(f"  📖 Ledger loaded — {len(ledger)} session(s) on record.")
        except Exception as e:
            print(f"  ⚠  Ledger load failed ({e}). Starting empty.")
    else:
        print(f"  📖 No ledger yet.")

    return ledger


# =============================================================================
# Ledger helpers
# =============================================================================

def ledger_record_epoch(
    ledger: dict,
    session_name: str,
    epoch: int,
    avg_reward: float,
    per_segment_rewards: list[float],
    affect_snapshot: dict,
) -> None:
    """
    Record epoch outcome + emotional snapshot into the ledger.
    The affect_snapshot captures how she felt at the end of the epoch —
    building a readable emotional arc across her training history.
    """
    if session_name not in ledger:
        ledger[session_name] = {
            "times_trained": 0,
            "best_reward":   0.0,
            "last_reward":   0.0,
            "history":       [],
        }

    entry = ledger[session_name]
    entry["times_trained"] += 1
    entry["last_reward"]    = round(avg_reward, 4)
    entry["best_reward"]    = round(max(entry["best_reward"], avg_reward), 4)
    entry["history"].append({
        "epoch":        epoch,
        "avg_reward":   round(avg_reward, 4),
        "min_segment":  round(min(per_segment_rewards), 4) if per_segment_rewards else 0.0,
        "max_segment":  round(max(per_segment_rewards), 4) if per_segment_rewards else 0.0,
        "affect":       affect_snapshot,   # emotional state at epoch end
        "timestamp":    datetime.utcnow().isoformat(),
    })


def ledger_should_skip(ledger: dict, session_name: str) -> bool:
    """Skip sessions already mastered above MASTERY_THRESHOLD."""
    if session_name not in ledger:
        return False
    best = ledger[session_name].get("best_reward", 0.0)
    if best >= MASTERY_THRESHOLD:
        print(
            f"  ✅ '{session_name}' mastered "
            f"(best: {best:.2f} / {MASTERY_THRESHOLD:.2f}). Skipping."
        )
        return True
    return False


def ledger_summary(ledger: dict) -> None:
    """Print concise session summary with emotional arc."""
    if not ledger:
        print("  Ledger empty — no sessions trained yet.")
        return

    print(f"\n  {'─' * 72}")
    print(f"  {'SESSION':<35} {'SEEN':>4}  {'BEST':>6}  {'LAST':>6}  {'MOOD':<12}  STATUS")
    print(f"  {'─' * 72}")

    for name, data in sorted(ledger.items()):
        status = "✅ mastered" if data["best_reward"] >= MASTERY_THRESHOLD else "🔄 learning"
        # Pull last mood from history if available
        mood = "—"
        if data["history"]:
            last_affect = data["history"][-1].get("affect", {})
            somatic     = last_affect.get("somatic", {})
            v = somatic.get("valence", 0.0)
            a = somatic.get("arousal", 0.0)
            p = somatic.get("pain",    0.0)
            if p > 0.5:
                mood = "pain"
            elif v > 0.3 and a > 0.4:
                mood = "excited"
            elif v > 0.3:
                mood = "content"
            elif v < -0.3 and a < 0.3:
                mood = "sad"
            elif v < -0.3:
                mood = "frustrated"
            else:
                mood = "neutral"

        print(
            f"  {name:<35} {data['times_trained']:>4}  "
            f"{data['best_reward']:>6.2f}  {data['last_reward']:>6.2f}  "
            f"{mood:<12}  {status}"
        )

    print(f"  {'─' * 72}\n")
