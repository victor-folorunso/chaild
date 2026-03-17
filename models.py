import torch
from transformers import (
    AutoProcessor,
    AutoModelForSpeechSeq2Seq,
    AutoModelForVision2Seq,
    WhisperProcessor,
    AutoTokenizer,
)
from mamba_ssm import Mamba
from qwen3_tts import Qwen3TTS  # pyright: ignore[reportMissingImports]

from config import (
    DEVICE,
    TORCH_DTYPE,
    VISION_MODEL_ID,
    AUDIO_MODEL_ID,
    TTS_MODEL_ID,
    VISION_EMB_DIM,
    AUDIO_EMB_DIM,
    MAMBA_DIM,
    AFFECT_DIM,
)

# =============================================================================
# Vision model — perception (frozen)
# =============================================================================
vision_model = AutoModelForVision2Seq.from_pretrained(
    VISION_MODEL_ID,
    torch_dtype=TORCH_DTYPE,
    device_map="auto",
    trust_remote_code=True,
).eval()
vision_processor = AutoProcessor.from_pretrained(VISION_MODEL_ID, trust_remote_code=True)
tokenizer        = AutoTokenizer.from_pretrained(VISION_MODEL_ID, trust_remote_code=True)

# =============================================================================
# Audio model — hearing (frozen)
# =============================================================================
audio_model = AutoModelForSpeechSeq2Seq.from_pretrained(
    AUDIO_MODEL_ID,
    torch_dtype=TORCH_DTYPE,
    device_map="auto",
).eval()
audio_processor = WhisperProcessor.from_pretrained(AUDIO_MODEL_ID)

# =============================================================================
# Trainable brain: projection → Mamba → lm_head
#
# projection input:  vision_emb [VISION_EMB_DIM]
#                  + audio_emb  [AUDIO_EMB_DIM]
#                  + affect_vec [AFFECT_DIM]        ← emotion fused here
#
# The affect vector enters on every forward pass, alongside what she
# sees and hears. Her emotional state is not a side channel — it is
# part of how she processes the world, exactly as it is for humans.
# =============================================================================
projection = torch.nn.Linear(
    VISION_EMB_DIM + AUDIO_EMB_DIM + AFFECT_DIM,
    MAMBA_DIM,
    dtype=TORCH_DTYPE,
    device=DEVICE,
)
mamba = Mamba(
    d_model=MAMBA_DIM,
    d_state=128,
    d_conv=4,
    expand=2,
).to(DEVICE).to(TORCH_DTYPE)
lm_head = torch.nn.Linear(
    MAMBA_DIM,
    tokenizer.vocab_size,
    dtype=TORCH_DTYPE,
    device=DEVICE,
)

# =============================================================================
# TTS — the voice (inference only)
# =============================================================================
tts_model = Qwen3TTS.from_pretrained(
    TTS_MODEL_ID,
    device_map="auto",
    torch_dtype=TORCH_DTYPE,
)
