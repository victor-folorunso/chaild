import torch
from transformers import Qwen3VLForConditionalGeneration, AutoProcessor, AutoModelForSpeechSeq2Seq, WhisperProcessor, AutoTokenizer
from mamba_ssm import Mamba
from qwen3_tts import Qwen3TTS

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
TORCH_DTYPE = torch.bfloat16

# --- Vision ---
vision_model = Qwen3VLForConditionalGeneration.from_pretrained(
    "Qwen/Qwen3-VL-72B-Instruct", torch_dtype=TORCH_DTYPE, device_map="auto", trust_remote_code=True
).eval()
vision_processor = AutoProcessor.from_pretrained("Qwen/Qwen3-VL-72B-Instruct", trust_remote_code=True)
tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen3-VL-72B-Instruct", trust_remote_code=True)

# --- Audio ---
audio_model = AutoModelForSpeechSeq2Seq.from_pretrained(
    "openai/whisper-large-v3", torch_dtype=TORCH_DTYPE, device_map="auto"
).eval()
audio_processor = WhisperProcessor.from_pretrained("openai/whisper-large-v3")

# --- Mamba ---
mamba = Mamba(dim=4096, d_state=128, d_conv=4, expand=2).to(DEVICE).to(TORCH_DTYPE).train()
projection = torch.nn.Linear(4096 + 1280, 4096, dtype=TORCH_DTYPE, device=DEVICE)
lm_head = torch.nn.Linear(4096, tokenizer.vocab_size, dtype=TORCH_DTYPE, device=DEVICE)

# --- TTS ---
tts_model = Qwen3TTS.from_pretrained("Qwen/Qwen3-TTS-1.7B", device_map="auto", torch_dtype=TORCH_DTYPE)