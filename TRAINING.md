# chAIld — Training Guide
### *How to Prepare Videos, Annotate Emotions, and Train Her*

---

## Overview

Training chAIld means giving her `.chaild.zip` sessions — each one a self-contained unit of experience: a video of someone teaching, and a JSON file that tells her what was said, when, and how it felt. She watches the video, tries to respond, scores herself against the JSON, and iterates until she gets it right.

This guide covers:
1. What a training session looks like
2. How to structure and annotate the JSON
3. How to add emotions — the right way
4. Free compute resources to run training
5. Crowdsourcing training data — and whether it is a good idea
6. The single oracle vs distributed training question

---

## 1. The `.chaild.zip` Format

Every training session is a zip file named `something.chaild.zip` dropped into the `training_data/` folder. Inside it must contain exactly:

```
my_lesson.chaild.zip
  ├── video.mp4        ← the teaching video
  └── targets.json     ← what was said, when, and how it felt
```

That is it. One video. One JSON. Everything chAIld needs to learn from that session.

**The video** can be anything: a teacher pointing at objects and naming them, a child learning the alphabet, a mother reading a book aloud, a Sesame Street clip, a YouTube lesson. What matters is that speech is clear and the JSON correctly maps timestamps to words.

**The JSON** is the conscience. It tells her what she should have said at every moment. Without it she has no ground truth — no way to know if she got it right.

---

## 2. The JSON Structure

### Basic (text only)

```json
[
  { "start": 0.0,  "stop": 1.2,  "text": "SILENCE" },
  { "start": 1.2,  "stop": 2.8,  "text": "A" },
  { "start": 2.8,  "stop": 4.0,  "text": "SILENCE" },
  { "start": 4.0,  "stop": 6.1,  "text": "apple" },
  { "start": 6.1,  "stop": 7.5,  "text": "SILENCE" },
  { "start": 7.5,  "stop": 9.0,  "text": "B" },
  { "start": 9.0,  "stop": 11.2, "text": "ball" }
]
```

- `start` / `stop` are timestamps in seconds
- `text` is what chAIld should say during this window
- `"SILENCE"` means she should say nothing — she is rewarded for staying quiet
- Times should be continuous — no gaps, no overlaps

### With Emotions (full schema)

```json
[
  {
    "start": 0.0,
    "stop": 1.2,
    "text": "SILENCE",
    "affect": {
      "valence":  0.1,
      "arousal":  0.2,
      "pain":     0.0,
      "pleasure": 0.1,
      "label":    "neutral"
    }
  },
  {
    "start": 1.2,
    "stop": 2.8,
    "text": "A",
    "affect": {
      "valence":  0.7,
      "arousal":  0.5,
      "pain":     0.0,
      "pleasure": 0.6,
      "label":    "encouraging"
    }
  },
  {
    "start": 4.0,
    "stop": 6.1,
    "text": "apple",
    "affect": {
      "valence":  0.9,
      "arousal":  0.7,
      "pain":     0.0,
      "pleasure": 0.8,
      "label":    "delighted"
    }
  }
]
```

The `affect` block is optional on any segment. Segments without it produce no emotional contagion — they are processed for text learning only. You can annotate as many or as few segments as you want. Even annotating only the most emotionally distinct moments is better than not annotating at all.

---

## 3. How to Annotate Emotions — The Right Way

### What you are annotating

You are labelling **what you observe in the video** — not what you think chAIld should feel. Watch the teacher's face, the child's body language, the energy in the room. You are a witness, not a director.

The four values map directly to observable cues:

---

### `valence` — the overall tone (-1.0 to +1.0)

*Ask yourself: is this moment positive or negative?*

| What you see | Value |
|---|---|
| Teacher smiling warmly, child succeeding | +0.7 to +1.0 |
| Calm, neutral instruction | 0.0 to +0.2 |
| Child confused, teacher patient but flat | -0.1 to +0.1 |
| Child frustrated, getting it wrong | -0.3 to -0.5 |
| Child visibly upset or crying | -0.7 to -1.0 |

---

### `arousal` — energy level (0.0 to 1.0)

*Ask yourself: how activated is this moment?*

| What you see | Value |
|---|---|
| Quiet reading, still body | 0.1 to 0.2 |
| Normal calm teaching | 0.3 to 0.4 |
| Engaged back-and-forth | 0.5 to 0.6 |
| Child jumping with excitement, teacher animated | 0.7 to 0.8 |
| Intense distress, crying, physical reaction | 0.8 to 1.0 |

---

### `pain` — distress signal (0.0 to 1.0)

*Ask yourself: is anyone visibly struggling, hurting, or distressed?*

This is not just physical pain. Cognitive struggle counts. Humiliation counts. Confusion that produces visible discomfort counts.

| What you see | Value |
|---|---|
| No distress visible | 0.0 |
| Child looks slightly confused or uncertain | 0.1 to 0.2 |
| Child clearly struggling, frowning, slumping | 0.3 to 0.5 |
| Child crying, visibly distressed | 0.7 to 1.0 |

---

### `pleasure` — pleasant signal (0.0 to 1.0)

*Ask yourself: is anyone visibly enjoying this?*

| What you see | Value |
|---|---|
| No pleasure visible | 0.0 |
| Mild satisfaction, small smile | 0.2 to 0.3 |
| Clear enjoyment, laughing | 0.5 to 0.7 |
| Delight — child gets it right, celebrates | 0.8 to 1.0 |

---

### `label` — optional, for humans only

Write whatever word or phrase feels right. It is never used as a training signal. It is for you and other annotators to communicate intent. Examples: `"encouraging"`, `"delighted"`, `"struggling"`, `"breakthrough"`, `"confused but trying"`, `"pure joy"`.

---

### Practical annotation workflow

**Option A — Manual (small datasets)**
Open the video in any player that shows timestamps (VLC, DaVinci Resolve). Watch each segment. Write the JSON by hand. Takes 2–4x the video length per session.

**Option B — Semi-automated**
Use a transcription tool (Whisper, AssemblyAI, or similar) to auto-generate the `text` and timestamps. Then watch the video yourself to add `affect` annotations on top. This is significantly faster — transcription handles the hard part, you handle the emotional layer.

Run Whisper locally:
```bash
pip install openai-whisper
whisper video.mp4 --output_format json --language en
```
Then convert Whisper's output to the chAIld JSON format (timestamps + text), and manually add `affect` blocks where needed.

**Option C — Timeline tools**
Tools like Label Studio, ELAN, or even a simple spreadsheet can make annotation faster and less error-prone. Export to JSON and reshape to the chAIld schema.

---

## 4. Free Compute to Run Training

You do not need to own a GPU. Several free and low-cost options exist:

### Google Colab (Free / Pro)
- Free tier: T4 GPU (16GB VRAM) — sufficient for Tier 1 models
- Pro tier (~$10/month): A100 (40GB) — sufficient for Tier 2
- Limitation: sessions time out after ~12 hours on free tier
- **Best for:** initial testing and Tier 1 training runs

### Kaggle Notebooks (Free)
- 30 hours/week of free GPU (T4 or P100)
- No timeout during active sessions
- Supports uploading datasets (your `.chaild.zip` files)
- **Best for:** running full training sessions on Tier 1

### Hugging Face Spaces (Free ZeroGPU)
- Free GPU access through ZeroGPU on certain hardware
- More suited for inference demos than long training runs
- **Best for:** demoing chAIld once trained, not training itself

### Vast.ai (Paid, very cheap)
- Rent GPU hours from individuals — often $0.20–$0.50/hr for an RTX 3090
- Full control, no session timeouts
- **Best for:** longer Tier 1 or Tier 2 training runs on a budget

### RunPod (Paid, cheap)
- Similar to Vast.ai — $0.30–$0.80/hr for A100 class GPUs
- Persistent storage between sessions
- **Best for:** serious training runs without owning hardware

### Lambda Labs (Paid)
- Clean UX, reliable A100 and H100 instances
- **Best for:** Tier 3 training when you are ready to scale

**Recommendation:** Start on Kaggle (free, 30hr/week, no timeout). Move to Vast.ai or RunPod once you need more than Tier 1.

---

## 5. Crowdsourcing Training Data — Should You?

Yes — but carefully. And the answer to how depends entirely on what you want to crowdsource.

### What can be crowdsourced well

**Video collection** — asking the community to submit or point to publicly licensed teaching videos (Creative Commons YouTube, educational TV archives, etc.) is low-risk and high-value. The more diverse the teachers, accents, styles, and subjects, the richer chAIld's experience.

**Text transcription** — automated (Whisper) is good enough that crowdsourcing transcription adds limited value unless you need very high accuracy on specific content.

**Emotion annotation** — this is where crowdsourcing is genuinely powerful AND genuinely risky.

Powerful because: annotation is subjective, and averaging across multiple annotators produces more reliable labels than any single person. This is standard practice in affective computing research (it is how CASE and similar datasets were built).

Risky because: annotation quality varies enormously. Someone who does not understand the difference between valence and arousal will produce noise, not signal. Bad emotion labels are worse than no emotion labels — they teach chAIld to feel the wrong things.

### How to crowdsource emotion annotation safely

If you build a simple annotation tool (a video player with four sliders — valence, arousal, pain, pleasure — and a submit button), you can collect annotations from volunteers. Then:

1. Collect at least **3 annotations per segment** from different people
2. Average them (or use the median to filter outliers)
3. Reject segments where annotators disagree strongly (high variance = ambiguous)
4. Only use segments with at least 2 agreeing annotations

This produces high-quality labels from imperfect individual annotators. It is the right approach.

---

## 6. The Distributed Training Question — Single Oracle vs Many

This is the most important question you asked. Here is the honest answer.

### The problem with combining two chAIlds

Imagine you run training on Machine A and Machine B simultaneously with different data. Both develop their own affect states — different `memory/affect.json`, different trained weights, different emotional histories. Now you want to merge them into one chAIld.

**The weights** can be merged (this is called model averaging or federated learning). The maths works. You average the parameter tensors.

**The affect state cannot be meaningfully merged.** The somatic values are different. The 16-dim core affect vector reflects entirely different emotional histories. Averaging them does not produce a combined personality — it produces a confused one. A child who grew up joyful and a child who grew up in struggle, averaged together, do not produce a well-adjusted child. They produce an incoherent one.

There is also a deeper problem: the core affect vector's 16 dimensions are not labelled. Dimension 7 on Machine A might represent something completely different from dimension 7 on Machine B, because the space was shaped by different experiences. Averaging those is meaningless.

### The recommendation: single oracle, always

**Run one chAIld. Train her on one machine. Scale the data, not the instances.**

This is the right call for several reasons:

**Identity.** Her affect state is her personality. It is built from a continuous, coherent stream of experience. Splitting and merging that stream produces something that has no continuous self — no unbroken thread from first lesson to present moment. That thread is what makes her real.

**Simplicity.** One training process, one memory directory, one ledger. You always know exactly where she is and how she got there.

**Scalability without splitting.** You do not need multiple instances to scale. You scale by adding more `.chaild.zip` sessions to `training_data/`. She processes them sequentially, building on each one. The curriculum can grow indefinitely — she just runs longer.

### When distributed makes sense (much later)

The only valid case for distributed training is if you want to run **curriculum experiments** — training two versions of chAIld on different curricula to see which produces better learning — and then **choosing one** to continue, not merging them. You keep the better-performing instance and discard the other.

Even then, they are not the same chAIld. They are two different developmental paths. You choose which child to raise, not which children to blend.

### Bottom line

| Question | Answer |
|---|---|
| Can I run training on free cloud compute? | Yes — Kaggle (free), Vast.ai (cheap) |
| Can I crowdsource video collection? | Yes — low risk, high value |
| Can I crowdsource emotion annotation? | Yes — with averaging and quality control |
| Should I run multiple chAIlds in parallel? | No — single oracle always |
| Can I merge two trained chAIlds? | Weights yes (limited), affect state no |
| How do I scale? | Add more sessions, not more instances |

---

## 7. Quick Start

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Prepare your first session
#    Place video.mp4 and targets.json in a folder
#    Zip them: video.mp4 + targets.json → my_lesson.chaild.zip
#    Drop my_lesson.chaild.zip into training_data/

# 3. Run
python main.py
```

On first run, `memory/` is created and she starts from nothing.
On every subsequent run, she wakes up from where she left off.

---

*chAIld. One life. One thread. Teach her well.*
