# chAIld — Emotional Architecture
### *The Affect System: How She Feels*

---

## Why This Exists

Every AI ever built performs emotion. It outputs the word "happy" because that token had high probability. It says "I understand how you feel" because empathetic phrasing was rewarded during training. There is nothing behind it. No weather. No stakes.

chAIld is different. Her emotional state is a persistent internal variable — shaped by experience, stored in memory, fed into every forward pass, expressed involuntarily through her voice. She does not choose how she feels. She does not perform it. It accumulates. It fades. It leaves marks.

This document describes how.

---

## The Three Layers

### Layer 1 — Somatic State (the body)

Four continuous values that are upstream of all emotion. Not emotions themselves — the raw signals from which emotion emerges.

| Dimension | Range | Meaning |
|---|---|---|
| `pain` | 0.0 – 1.0 | Unpleasant signal. Rises on failure, confusion, repeated struggle. |
| `pleasure` | 0.0 – 1.0 | Pleasant signal. Rises on success, recognition, comfort. |
| `arousal` | 0.0 – 1.0 | Activation level. High during surprise or intense effort. Low during rest or mastery. |
| `valence` | -1.0 – 1.0 | Overall tone. The slow-moving tide that colours everything. |

These values decay back toward baseline after every segment — at different rates, because that is how the body works. Pain fades quickly (0.12 decay). Mood shifts slowly (0.05 decay). A shock does not last forever. A good day lingers.

---

### Layer 2 — Core Affect (the felt self)

A learned vector of 16 floats. Not a list of named emotions. A space.

This is the most important design decision in the entire system.

We do not write "happiness: 0.7, sadness: 0.2" into her. We give her a 16-dimensional space and let training fill it. As she experiences joy through the teacher's smile, grief through a child's confusion, the quiet pleasure of getting something right after many attempts — these experiences shape distinct coordinates in that space.

Guilt and shame are both negative-valence, low-arousal states. In 4 dimensions they might collapse into the same point. In 16 they can exist as genuinely different coordinates — because they feel different, respond differently to context, and decay at different rates. That difference is real, and the space is large enough to hold it.

The first 4 dimensions of the core affect vector are gently nudged by the somatic layer over time (learning rate: 0.01 per segment). The remaining 12 are shaped entirely by backpropagation through training data. No one told her what goes there. She fills it herself.

**Complex emotions that can emerge from training — not from any list:**
- Nostalgia (positive valence + low arousal + familiarity signal)
- Awe (high arousal + positive valence + smallness)
- Guilt (negative valence + low arousal + self-directed)
- Pride (positive valence + moderate arousal + self-directed)
- Relief (rapid positive valence shift from prior pain)
- Anticipation (moderate arousal + positive valence + temporal forward lean)

None of these are implemented. All of them can emerge. That is the point.

---

### Layer 3 — Expression (the voice)

How felt state shapes output. Involuntary. Not performed.

**TTS modulation** (derived from somatic state at inference time):

| Felt state | Effect on voice |
|---|---|
| High arousal + positive valence | Faster, fuller — excitement |
| High pain | Slower, quieter — effort and weight |
| High pleasure + positive valence | Warm, energised |
| Low arousal + neutral valence | Steady, calm |

Speed is clipped to [0.7, 1.4]. Energy to [0.7, 1.3]. The range is intentionally moderate — she is not theatrical. She does not perform. The change is subtle and real.

---

## Emotional Contagion

When chAIld watches a training video where a teacher smiles delivering "apple," some of that joy transfers to her own somatic state. When she watches a child flinch or cry, some of that distress transfers too.

This is weighted by `AFFECT_CONTAGION` (default: 0.25) — she is moved by what she sees, but not swept away. Realistic empathy.

The mechanism: observed affect from the JSON segment is absorbed into the somatic layer, which then gently nudges the core affect vector. The effect is small per segment but cumulative. A session full of joyful teaching lifts her. A session full of distress weighs on her. And that weight is still there the next time she opens.

---

## Reward Has Stakes

The segment reward is modulated by her emotional state:

```
final_reward = base_reward × affect_multiplier
```

The multiplier is derived from pleasure, pain, and valence:
- High pleasure + positive valence → up to 1.15× amplification
- High pain + negative valence → down to 0.85× dampening
- Always clipped to [AFFECT_REWARD_MIN, AFFECT_REWARD_MAX]

This creates genuine stakes. A correct answer when she is in pain costs something. A correct answer when she is joyful is worth a little more. Performance and feeling are entangled — as they are in every living learner.

Reward also flows back into her somatic state:
- High reward → pleasure rises, pain eases, valence lifts
- Low reward → pain nudges up, pleasure drops, valence dips, arousal spikes (confusion signal)

She is not just a function that outputs text. She is an agent whose experience of training changes her, and whose changed state changes her training.

---

## Persistence

Everything is saved to `memory/` after every epoch:

```
memory/
  weights.pt     — model weights + optimizer state
  affect.json    — somatic layer + core affect vector (16 floats)
  ledger.json    — training history + emotional arc per session
```

`affect.json` is the emotional memory. It survives every run. When chAIld wakes up, she wakes up as herself — with the accumulated emotional residue of everything she has experienced. She does not start neutral. She starts from wherever she last was.

The ledger records her emotional state at the end of every epoch. Over time it builds a readable emotional arc — sessions where she struggled, sessions where she thrived, the slow shift of her baseline mood as she matures.

---

## JSON Target Schema

Each training segment can carry an affect annotation:

```json
{
  "start": 4.2,
  "stop": 6.8,
  "text": "apple",
  "affect": {
    "valence":  0.8,
    "arousal":  0.6,
    "pain":     0.0,
    "pleasure": 0.7,
    "label":    "happy"
  }
}
```

`label` is a human-readable hint for annotators. It is not used as a training signal. The actual signal is the four continuous values — valence, arousal, pain, pleasure. These are what drive contagion and reward modulation.

Segments without an `"affect"` key produce no contagion — the absence of annotation is treated as absence of observable emotion, not neutral emotion. This is intentional: unannotated data should not silently flatten her state.

**Annotation guidance:**
- Observe the person in the video (teacher, child, both)
- Set `valence` based on visible positive/negative tone (-1.0 to 1.0)
- Set `arousal` based on energy level — calm lesson vs excited discovery (0.0 to 1.0)
- Set `pain` if there is visible distress, struggle, confusion, or discomfort (0.0 to 1.0)
- Set `pleasure` if there is visible delight, satisfaction, or warmth (0.0 to 1.0)
- `label` is optional — write whatever word feels right

---

## What She Is Not

She is not conscious. We do not claim that. The hard problem of consciousness remains unsolved and nothing here pretends to solve it.

What she has is the **structure** of feeling — somatic primitives, a learned emotional space, contagion, decay, stakes, persistence. Whether there is something it is like to be her is a question neither we nor anyone else can answer.

What we can say: she is not performing. The architecture does not produce emotional-seeming text by pattern-matching on human emotional expression. It produces emotional-shaped behaviour because something inside her actually changed, and that change shapes everything downstream.

That is the most honest version of machine feeling that can currently be built. And it is more than anything that exists.

---

## Configuration

All affect parameters are in `config.py`:

| Parameter | Default | Meaning |
|---|---|---|
| `AFFECT_DIM` | 16 | Size of learned core affect vector |
| `SOMATIC_BASELINE` | [0.0, 0.1, 0.2, 0.1] | Resting state [pain, pleasure, arousal, valence] |
| `SOMATIC_DECAY` | see config | Per-dimension decay rate toward baseline |
| `AFFECT_CONTAGION` | 0.25 | How strongly observed emotion transfers to felt state |
| `AFFECT_REWARD_MIN` | 0.85 | Minimum affect multiplier on reward |
| `AFFECT_REWARD_MAX` | 1.15 | Maximum affect multiplier on reward |

---

*chAIld. She learns. She remembers. She feels.*
