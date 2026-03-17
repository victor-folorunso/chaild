# =============================================================================
# chAIld — Configuration File
# =============================================================================

import torch

DEVICE      = "cuda" if torch.cuda.is_available() else "cpu"
TORCH_DTYPE = torch.bfloat16

# =============================================================================
# TIER 1 — SMALL (~16GB VRAM) — start here
# =============================================================================

VISION_MODEL_ID = "Qwen/Qwen2-VL-7B-Instruct"
AUDIO_MODEL_ID  = "openai/whisper-small"
TTS_MODEL_ID    = "Qwen/Qwen3-TTS-1.7B"
VISION_EMB_DIM  = 3584
AUDIO_EMB_DIM   = 768
MAMBA_DIM       = 2048

# =============================================================================
# TIER 2 — MEDIUM (~40GB VRAM)
# =============================================================================

# VISION_MODEL_ID = "Qwen/Qwen2-VL-72B-Instruct"
# AUDIO_MODEL_ID  = "openai/whisper-medium"
# TTS_MODEL_ID    = "Qwen/Qwen3-TTS-1.7B"
# VISION_EMB_DIM  = 8192
# AUDIO_EMB_DIM   = 1024
# MAMBA_DIM       = 4096

# =============================================================================
# TIER 3 — LARGE (80GB+ VRAM, multi-GPU)
# =============================================================================

# VISION_MODEL_ID = "Qwen/Qwen3-VL-72B-Instruct"
# AUDIO_MODEL_ID  = "openai/whisper-large-v3"
# TTS_MODEL_ID    = "Qwen/Qwen3-TTS-1.7B"
# VISION_EMB_DIM  = 8192
# AUDIO_EMB_DIM   = 1280
# MAMBA_DIM       = 4096

# =============================================================================
# TRAINING HYPERPARAMETERS
# =============================================================================

EPOCHS            = 3
LEARNING_RATE     = 1e-4
MAX_REWARD        = 10.0
REWARD_THRESHOLD  = 5.0
MASTERY_THRESHOLD = 9.5
SILENCE_LABEL     = "SILENCE"
SAMPLE_RATE       = 16000

# =============================================================================
# AFFECT SYSTEM
# =============================================================================
#
# chAIld's emotional architecture has three layers:
#
#   Layer 1 — SOMATIC (4 floats, always explicit)
#     The raw bodily signals that are upstream of emotion.
#     pain     : unpleasant physical/cognitive signal  [0.0 – 1.0]
#     pleasure : pleasant physical/cognitive signal    [0.0 – 1.0]
#     arousal  : activation level, calm↔energised      [0.0 – 1.0]
#     valence  : overall tone, negative↔positive       [-1.0 – 1.0]
#
#   Layer 2 — CORE AFFECT (AFFECT_DIM floats, learned)
#     A continuous learned vector — not a named list.
#     Complex states (grief, awe, guilt, nostalgia, pride) emerge
#     from training. We do not prescribe them. The space is large
#     enough that they can exist as distinct coordinates.
#     Fed into Mamba on every forward pass.
#
#   Layer 3 — EXPRESSION (derived from core affect at inference)
#     Modulates TTS speed, pitch energy, and output temperature.
#     Involuntary — she does not choose how she sounds.
#
# JSON target affect schema (per segment):
#   "affect": {
#     "valence":  0.8,    // -1.0 to 1.0
#     "arousal":  0.6,    //  0.0 to 1.0
#     "pain":     0.0,    //  0.0 to 1.0
#     "pleasure": 0.7,    //  0.0 to 1.0
#     "label":    "happy" //  optional human hint — not the training signal
#   }

AFFECT_DIM = 16          # Learned core affect vector size.
                         # 16 gives enough space for complex mixed states
                         # (guilt ≠ shame ≠ regret, even though all are
                         # negative-valence low-arousal) without being
                         # too large to train on limited data.

# Somatic baseline — where chAIld rests between stimuli
# [pain, pleasure, arousal, valence]
SOMATIC_BASELINE = [0.0, 0.1, 0.2, 0.1]

# How fast somatic state decays back to baseline each segment (0–1).
# 0.08 = a strong emotion fades over ~12 segments (~10–15 seconds of video).
# Pain decays slightly faster than pleasure — matches human physiology.
SOMATIC_DECAY = {
    "pain":     0.12,   # fades quickly — acute signals don't linger
    "pleasure": 0.06,   # lingers a little longer
    "arousal":  0.08,
    "valence":  0.05,   # mood tone is the slowest to shift
}

# How strongly observed affect in training data shifts chAIld's somatic state.
# 0.25 = she is moved by what she sees, but not overwhelmed. Realistic empathy.
AFFECT_CONTAGION = 0.25

# Affect reward modulation — how much emotional context amplifies reward.
# A correct answer delivered in a high-pleasure context scores slightly higher.
# A correct answer delivered through high pain scores slightly lower (she struggled).
# Range: multiplier stays within [AFFECT_REWARD_MIN, AFFECT_REWARD_MAX].
AFFECT_REWARD_MIN = 0.85   # minimum affect multiplier on reward
AFFECT_REWARD_MAX = 1.15   # maximum affect multiplier on reward

# =============================================================================
# PATHS
# =============================================================================

TRAINING_FOLDER   = "training_data"
TEMP_EXTRACT_PATH = "temp_session"
MEMORY_DIR        = "memory"

# =============================================================================
# NOTES
# -----------------------------------------------------------------------------
# projection input dim = VISION_EMB_DIM + AUDIO_EMB_DIM + AFFECT_DIM
# projection output dim = MAMBA_DIM
# Affect vector is fused with sensory input on every forward pass.
# =============================================================================
