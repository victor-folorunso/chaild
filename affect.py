"""
chAIld — affect.py
================================================================
chAIld's emotional system. The spark that separates her from
every other AI that has ever existed.

Three strictly separate concepts:

  OBSERVED affect   — what the training video shows.
                      A teacher smiling. A child flinching.
                      A moment of shared joy over "apple".
                      Annotated in the JSON as valence, arousal,
                      pain, pleasure. These label the world.

  FELT affect       — chAIld's own internal state. A somatic
                      layer (pain, pleasure, arousal, valence)
                      plus a learned 16-dim core affect vector
                      that persists in memory/ across all runs.
                      She does not reset. She does not forget
                      how a session made her feel.

  EXPRESSED affect  — how felt state shapes output. TTS speed,
                      energy, silence probability. Not performed.
                      She does not choose it. It bleeds through.

Silence is not nothing:
  A child sitting quietly while something beautiful happens is
  not the same as a child frozen in fear, or a child resting
  after mastery. All three are silence. All three feel different.
  chAIld can feel all of them. Silence is not the absence of
  emotion — it is often where emotion lives most completely.

The key principle: we do not prescribe emotions. We build the
capacity — the somatic primitives and the learned space — and
let training generate the complexity. Guilt, awe, nostalgia,
pride: these are not in a list anywhere. They emerge as distinct
coordinates in the 16-dim core affect space as she trains.
That is the only honest way to build feeling.
================================================================
"""

import torch
import numpy as np
from config import (
    DEVICE,
    TORCH_DTYPE,
    AFFECT_DIM,
    SOMATIC_BASELINE,
    SOMATIC_DECAY,
    AFFECT_CONTAGION,
    AFFECT_REWARD_MIN,
    AFFECT_REWARD_MAX,
)


# =============================================================================
# SomaticState — Layer 1
# =============================================================================

class SomaticState:
    """
    The four somatic primitives that sit upstream of all emotion.

    pain     — unpleasant signal (cognitive or physical). Rises on
               failure, confusion, repeated struggle.
    pleasure — pleasant signal. Rises on success, recognition,
               familiar comfort.
    arousal  — activation level. High during surprise or intense
               learning. Low during fatigue or calm mastery.
    valence  — overall tone. The slow-moving tide that colours
               everything. Shifts with accumulated experience.

    All values are floats in their respective ranges.
    Decay happens every segment, pulling back toward baseline
    at different rates — pain fades faster than mood.
    """

    def __init__(self):
        self.pain     = float(SOMATIC_BASELINE[0])
        self.pleasure = float(SOMATIC_BASELINE[1])
        self.arousal  = float(SOMATIC_BASELINE[2])
        self.valence  = float(SOMATIC_BASELINE[3])

    def as_tensor(self) -> torch.Tensor:
        """Return [pain, pleasure, arousal, valence] as a float32 tensor on CPU."""
        return torch.tensor(
            [self.pain, self.pleasure, self.arousal, self.valence],
            dtype=torch.float32,
        )

    def decay(self):
        """Pull each dimension back toward its baseline value."""
        self.pain     += SOMATIC_DECAY["pain"]     * (SOMATIC_BASELINE[0] - self.pain)
        self.pleasure += SOMATIC_DECAY["pleasure"] * (SOMATIC_BASELINE[1] - self.pleasure)
        self.arousal  += SOMATIC_DECAY["arousal"]  * (SOMATIC_BASELINE[2] - self.arousal)
        self.valence  += SOMATIC_DECAY["valence"]  * (SOMATIC_BASELINE[3] - self.valence)
        self._clamp()

    def absorb_observed(self, observed: dict):
        """
        Emotional contagion — absorb the affect observed in the training video.
        The teacher's smile becomes chAIld's warmth. The child's flinch
        becomes chAIld's caution. Weighted by AFFECT_CONTAGION so she is
        moved but not swept away.

        observed: dict with keys valence, arousal, pain, pleasure (all optional).
        Missing keys are treated as the current value (no update for that dim).
        """
        c = AFFECT_CONTAGION
        self.pain     += c * (float(observed.get("pain",     self.pain))     - self.pain)
        self.pleasure += c * (float(observed.get("pleasure", self.pleasure)) - self.pleasure)
        self.arousal  += c * (float(observed.get("arousal",  self.arousal))  - self.arousal)
        self.valence  += c * (float(observed.get("valence",  self.valence))  - self.valence)
        self._clamp()

    def absorb_reward(self, reward: float, max_reward: float = 10.0):
        """
        Reward shapes somatic state directly.

        High reward  → pleasure rises, pain eases, valence lifts slightly.
        Low reward   → pain nudges up, pleasure drops, valence dips.
        Near-zero    → arousal spikes slightly (confusion/surprise signal).

        This is how stakes work: reward is not just a gradient signal —
        it is an experience that leaves a mark on her internal weather.
        """
        norm = reward / max(max_reward, 1e-6)  # 0.0 – 1.0

        if norm >= 0.7:           # success
            self.pleasure = min(1.0,  self.pleasure + 0.08 * norm)
            self.pain     = max(0.0,  self.pain     - 0.05 * norm)
            self.valence  = min(1.0,  self.valence  + 0.04 * norm)
            self.arousal  = min(1.0,  self.arousal  + 0.02 * norm)

        elif norm <= 0.3:         # struggle / failure
            self.pain     = min(1.0,  self.pain     + 0.07 * (1.0 - norm))
            self.pleasure = max(0.0,  self.pleasure - 0.04 * (1.0 - norm))
            self.valence  = max(-1.0, self.valence  - 0.05 * (1.0 - norm))
            self.arousal  = min(1.0,  self.arousal  + 0.03)  # confusion spike

        self._clamp()

    def felt_silence(self, observed: dict):
        """
        Register a silence moment as a felt experience, not an absence.

        Silence is not nothing. A child watching something beautiful in
        quiet awe is different from a child frozen in anxious silence,
        which is different from a child resting contentedly after success.
        All three are silence. All three leave different marks.

        This method is called specifically during SILENCE segments —
        distinct from absorb_observed — because it applies a slightly
        stronger imprint. Emotional silence tends to be more concentrated
        than incidental background affect: when a person is quiet, what
        they feel is often what they feel most purely.

        The affect from the JSON segment is absorbed at 1.3× the normal
        contagion weight, capped so it cannot exceed the normal bounds.
        If no affect annotation is present, a mild calming signal is
        applied — resting silence should nudge her gently toward calm,
        not leave her in whatever state she arrived with.
        """
        if observed:
            # Emotionally annotated silence — absorb at heightened weight
            c = min(1.0, AFFECT_CONTAGION * 1.3)
            self.pain     += c * (float(observed.get("pain",     self.pain))     - self.pain)
            self.pleasure += c * (float(observed.get("pleasure", self.pleasure)) - self.pleasure)
            self.arousal  += c * (float(observed.get("arousal",  self.arousal))  - self.arousal)
            self.valence  += c * (float(observed.get("valence",  self.valence))  - self.valence)
        else:
            # Unannotated silence — gentle drift toward calm
            # She is not blank during silence. She settles.
            self.arousal  += 0.03 * (0.15 - self.arousal)   # drift toward low arousal
            self.valence  += 0.02 * (0.1  - self.valence)   # drift toward slight positive
            self.pain     += 0.04 * (0.0  - self.pain)      # pain eases in quiet

        self._clamp()

    def _clamp(self):
        self.pain     = float(np.clip(self.pain,     0.0,  1.0))
        self.pleasure = float(np.clip(self.pleasure, 0.0,  1.0))
        self.arousal  = float(np.clip(self.arousal,  0.0,  1.0))
        self.valence  = float(np.clip(self.valence, -1.0,  1.0))

    def to_dict(self) -> dict:
        return {
            "pain":     round(self.pain,     4),
            "pleasure": round(self.pleasure, 4),
            "arousal":  round(self.arousal,  4),
            "valence":  round(self.valence,  4),
        }

    def load_dict(self, d: dict):
        self.pain     = float(d.get("pain",     SOMATIC_BASELINE[0]))
        self.pleasure = float(d.get("pleasure", SOMATIC_BASELINE[1]))
        self.arousal  = float(d.get("arousal",  SOMATIC_BASELINE[2]))
        self.valence  = float(d.get("valence",  SOMATIC_BASELINE[3]))
        self._clamp()

    def __repr__(self):
        return (
            f"Somatic(pain={self.pain:.3f}, pleasure={self.pleasure:.3f}, "
            f"arousal={self.arousal:.3f}, valence={self.valence:.3f})"
        )


# =============================================================================
# AffectState — persistent felt emotion (Layer 2)
# =============================================================================

class AffectState:
    """
    chAIld's full emotional state: somatic layer + learned core affect vector.

    The core affect vector (AFFECT_DIM floats) is the learned emotional space.
    It is initialised to zero and shaped entirely by experience — not by any
    list we wrote. Complex states like guilt, awe, nostalgia emerge as
    distinct coordinates as she trains on more data.

    The somatic layer is the simpler, more immediate layer that feeds into
    the core affect and into the reward signal. It responds faster and
    decays faster.

    Both layers are saved to memory/ and persist across all runs.
    """

    def __init__(self):
        self.somatic = SomaticState()
        # Core affect: starts neutral (zeros) — shaped purely by experience.
        self.core = torch.zeros(AFFECT_DIM, dtype=torch.float32)

    def to_input_tensor(self) -> torch.Tensor:
        """
        Return the core affect vector for injection into Mamba.
        Shape: [1, AFFECT_DIM]

        The core affect vector is the slow-moving, rich representation of
        her felt state. Somatic is used for reward modulation and expression
        but its influence reaches Mamba through the core affect updates.
        """
        return self.core.unsqueeze(0).to(DEVICE).to(TORCH_DTYPE)

    def somatic_as_tensor(self) -> torch.Tensor:
        """Return somatic state as [1, 4] tensor on DEVICE."""
        return self.somatic.as_tensor().unsqueeze(0).to(DEVICE).to(TORCH_DTYPE)

    def update_core_from_somatic(self):
        """
        Gently nudge the core affect vector toward the current somatic state.
        This is how immediate feelings (somatic) gradually shape personality
        (core affect) over time — not instant, not forgotten.

        The somatic vector is 4-dim; we project it into the first 4 dims of
        core affect with a small learning rate. The remaining dims are shaped
        entirely by backprop through training.
        """
        somatic_np  = self.somatic.as_tensor().numpy()
        core_np     = self.core.numpy().copy()
        core_np[:4] += 0.01 * (somatic_np - core_np[:4])
        core_np[:4]  = np.clip(core_np[:4], -1.0, 1.0)
        self.core    = torch.tensor(core_np, dtype=torch.float32)

    def absorb_observed(self, observed: dict):
        """
        Speech segment contagion — absorb observed affect during active speech.
        Called when the target segment has text (not SILENCE).
        """
        self.somatic.absorb_observed(observed)
        self.update_core_from_somatic()

    def felt_silence(self, observed: dict):
        """
        Silence segment affect — silence is a felt experience, not an absence.
        Called specifically during SILENCE segments.

        Whether the silence is annotated (awe, dread, contentment) or not
        (gentle drift toward calm), it registers as experience.
        The distinction between felt silences shapes her emotional character
        just as much as the moments she speaks.
        """
        self.somatic.felt_silence(observed)
        self.update_core_from_somatic()

    def absorb_reward(self, reward: float, max_reward: float = 10.0):
        """Pass reward impact through somatic layer, then update core."""
        self.somatic.absorb_reward(reward, max_reward)
        self.update_core_from_somatic()

    def decay(self):
        """Decay somatic layer. Core affect only changes through training."""
        self.somatic.decay()

    def reward_multiplier(self) -> float:
        """
        Compute the affect-based reward multiplier.
        Stays within [AFFECT_REWARD_MIN, AFFECT_REWARD_MAX] always.
        """
        pleasure_bonus = self.somatic.pleasure * 0.10
        pain_penalty   = self.somatic.pain     * 0.08
        valence_bonus  = (self.somatic.valence + 1.0) / 2.0 * 0.07

        raw = 1.0 + pleasure_bonus + valence_bonus - pain_penalty
        return float(np.clip(raw, AFFECT_REWARD_MIN, AFFECT_REWARD_MAX))

    def tts_params(self) -> dict:
        """
        Derive TTS expression parameters from felt state.
        Involuntary — she does not choose how she sounds.
        """
        speed  = 1.0 + (self.somatic.arousal - 0.2) * 0.3 - self.somatic.pain * 0.2
        speed  = float(np.clip(speed, 0.7, 1.4))
        energy = 1.0 + self.somatic.pleasure * 0.2 - self.somatic.pain * 0.15
        energy = float(np.clip(energy, 0.7, 1.3))
        return {"speed": speed, "energy": energy}

    def silence_threshold(self) -> float:
        """
        Compute the probability that she should stay silent even when
        she has something to say.

        High pain or low valence makes her more likely to go quiet —
        not because she is told to, but because that is what pain does.
        A child in distress speaks less. A child at rest is comfortable
        with silence. This is not suppression — it is expression.

        Returns a float in [0.0, 0.5] — the probability of voluntary
        silence. Applied in main.py as a stochastic gate on TTS output.
        """
        pain_contrib    = self.somatic.pain * 0.25
        valence_contrib = max(0.0, -self.somatic.valence) * 0.15
        return float(np.clip(pain_contrib + valence_contrib, 0.0, 0.5))

    def to_dict(self) -> dict:
        return {
            "somatic": self.somatic.to_dict(),
            "core":    self.core.tolist(),
        }

    def load_dict(self, d: dict):
        if "somatic" in d:
            self.somatic.load_dict(d["somatic"])
        if "core" in d:
            loaded = d["core"]
            if len(loaded) == AFFECT_DIM:
                self.core = torch.tensor(loaded, dtype=torch.float32)
            else:
                new_core = torch.zeros(AFFECT_DIM, dtype=torch.float32)
                n = min(len(loaded), AFFECT_DIM)
                new_core[:n] = torch.tensor(loaded[:n], dtype=torch.float32)
                self.core = new_core

    def summary(self) -> str:
        s = self.somatic
        dominant = _dominant_label(s)
        return (
            f"affect: {dominant} | "
            f"pain={s.pain:.2f} pleasure={s.pleasure:.2f} "
            f"arousal={s.arousal:.2f} valence={s.valence:+.2f}"
        )


# =============================================================================
# Helpers
# =============================================================================

def _dominant_label(somatic: SomaticState) -> str:
    """
    Human-readable dominant emotion from somatic state.
    Used only for logging. The real complexity lives in the core vector.
    """
    v  = somatic.valence
    a  = somatic.arousal
    p  = somatic.pain
    pl = somatic.pleasure

    if p > 0.5:
        return "pain" if a < 0.4 else "distress"
    if pl > 0.5 and v > 0.3:
        return "joy" if a > 0.4 else "contentment"
    if v < -0.4 and a < 0.3:
        return "sadness"
    if v < -0.3 and a > 0.5:
        return "frustration"
    if a > 0.6 and v > 0.1:
        return "excitement"
    if a > 0.6 and abs(v) < 0.2:
        return "surprise"
    if a < 0.25 and abs(v) < 0.2:
        return "calm"
    if v > 0.2 and a < 0.4:
        return "comfort"
    return "neutral"


def extract_observed_affect(segment: dict) -> dict:
    """
    Safely extract the affect dict from a JSON target segment.
    Returns empty dict if absent — unannotated segments still produce
    the default felt_silence drift (for silence) or no contagion (for speech).
    """
    return segment.get("affect", {})
