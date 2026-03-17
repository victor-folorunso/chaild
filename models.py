import torch
from accelerate import Accelerator # pyright: ignore[reportMissingImports]
from transformers import Qwen3VLForConditionalGeneration, AutoProcessor, AutoModelForSpeechSeq2Seq, WhisperProcessor, AutoTokenizer # pyright: ignore[reportMissingImports]
from mamba_ssm import Mamba # pyright: ignore[reportMissingImports]
from qwen3_tts import Qwen3TTS # pyright: ignore[reportMissingImports]

accelerator = Accelerator()
device = accelerator.device
torch_dtype = torch.bfloat16

vision_model = Qwen3VLForConditionalGeneration.from_pretrained(
    "Qwen/Qwen3-VL-72B-Instruct", torch_dtype=torch_dtype, device_map="auto", trust_remote_code=True
).eval()
vision_processor = AutoProcessor.from_pretrained("Qwen/Qwen3-VL-72B-Instruct", trust_remote_code=True)
tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen3-VL-72B-Instruct", trust_remote_code=True)

audio_model = AutoModelForSpeechSeq2Seq.from_pretrained(
    "openai/whisper-large-v3", torch_dtype=torch_dtype, device_map="auto"
).eval()
audio_processor = WhisperProcessor.from_pretrained("openai/whisper-large-v3")

mamba = Mamba(dim=4096, d_state=128, d_conv=4, expand=2).to(device).to(torch_dtype).eval()
projection = torch.nn.Linear(4096 + 1280, 4096, dtype=torch_dtype, device=device)

lm_head = torch.nn.Linear(4096, 151936, dtype=torch_dtype, device=device)

tts_model = Qwen3TTS.from_pretrained("Qwen/Qwen3-TTS-1.7B", device_map="auto", torch_dtype=torch_dtype)

print("All enterprise models loaded.")