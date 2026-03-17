from rapidfuzz.distance import Levenshtein  # pyright: ignore[reportMissingImports]
from rapidfuzz import fuzz # pyright: ignore[reportMissingImports]
import jellyfish  # pyright: ignore[reportMissingImports]


# =============================================================================
# Text similarity
# =============================================================================

def _phonetic_similarity(pred_text: str, target_text: str) -> float:
    """
    Word-level phonetic similarity using Soundex.
    Catches "cat"≈"kat", "apple"≈"aple" — things Levenshtein misses.
    Critical for a speech learner whose output is often phonetically close
    but not yet orthographically correct. Returns 0.0–1.0.
    """
    pred_words   = pred_text.lower().split()
    target_words = target_text.lower().split()

    if not pred_words and not target_words:
        return 1.0
    if not pred_words or not target_words:
        return 0.0

    scores = []
    for t_word in target_words:
        t_code = jellyfish.soundex(t_word)
        best   = max(
            (1.0 if jellyfish.soundex(p_word) == t_code else 0.0
             for p_word in pred_words),
            default=0.0,
        )
        scores.append(best)

    return sum(scores) / len(scores)


def compute_similarity(pred_text: str, target_text: str) -> float:
    """
    Composite text similarity:
      50% Levenshtein  — character-level structural accuracy
      20% Token sort   — handles word reordering
      30% Phonetic     — sounds-like matching

    Returns 0.0–1.0.
    """
    pred_text   = pred_text.lower().strip()
    target_text = target_text.lower().strip()

    if not pred_text and not target_text:
        return 1.0
    if not pred_text or not target_text:
        return 0.0

    max_len      = max(len(pred_text), len(target_text))
    lev_sim      = max(0.0, (max_len - Levenshtein.distance(pred_text, target_text)) / max_len)
    token_sim    = fuzz.token_sort_ratio(pred_text, target_text) / 100.0
    phonetic_sim = _phonetic_similarity(pred_text, target_text)

    return 0.5 * lev_sim + 0.2 * token_sim + 0.3 * phonetic_sim


# =============================================================================
# Segment scoring — with affect modulation
# =============================================================================

def score_segment(
    pred_text: str,
    target_text: str,
    is_silence: bool,
    duration: float,
    affect_multiplier: float = 1.0,
    max_reward: float = 10.0,
) -> float:
    """
    Reward for a single segment.

    Factors:
      1. Text similarity     — how close is what she said to what she should say
      2. Duration weight     — longer correct segments earn more (up to 2s cap)
      3. Affect multiplier   — her emotional state modulates the final reward

    The affect multiplier is derived from AffectState.reward_multiplier().
    It stays in [AFFECT_REWARD_MIN, AFFECT_REWARD_MAX] — typically 0.85–1.15.
    This means:
      - A correct answer in a high-pleasure, positive-valence state earns
        slightly more. Feeling good reinforces good performance.
      - A correct answer through high pain earns slightly less. The struggle
        is acknowledged. She is not punished further, but the cost is real.
      - This creates genuine stakes: her emotional state has consequences.

    Silence segments:
        Full reward if nothing said. Penalised by output length.
    Speech segments:
        Partial credit via composite similarity.
    """
    duration_weight = min(1.0, duration / 2.0)

    if is_silence:
        output_len     = len(pred_text.strip())
        penalty_factor = min(1.0, output_len / 10.0)
        raw            = max(0.0, 1.0 - penalty_factor)
    else:
        raw = compute_similarity(pred_text, target_text)

    base_reward = max_reward * duration_weight * raw
    return round(base_reward * affect_multiplier, 4)


# =============================================================================
# Full-video scoring
# =============================================================================

def score_full_video(
    predictions: list[dict],
    targets: list[dict],
    max_reward: float = 10.0,
) -> tuple[float, list[float]]:
    """
    Full-video aggregate scoring. Matches predictions to targets by time
    overlap — robust to off-by-one frame issues and partial coverage.

    predictions : [{"start", "stop", "pred_text"}, ...]
    targets     : [{"start", "stop", "text", "affect"(optional)}, ...]

    Note: full-video scoring does not apply affect modulation — it uses
    raw text similarity only, so the aggregate reward is comparable across
    sessions regardless of emotional context during that epoch.

    Returns:
        avg_reward      (float) : mean reward across all target segments
        segment_rewards (list)  : per-segment raw rewards in target order
    """
    segment_rewards = []

    for seg_target in targets:
        t_start    = seg_target["start"]
        t_stop     = seg_target["stop"]
        t_text     = seg_target["text"]
        is_silence = t_text.upper() == "SILENCE"
        duration   = t_stop - t_start

        best_pred    = ""
        best_overlap = 0.0
        for seg_pred in predictions:
            overlap = max(
                0.0,
                min(seg_pred["stop"], t_stop) - max(seg_pred["start"], t_start)
            )
            if overlap > best_overlap:
                best_overlap = overlap
                best_pred    = seg_pred["pred_text"]

        # No affect multiplier here — raw scoring for comparable epoch metrics
        reward = score_segment(best_pred, t_text, is_silence, duration,
                               affect_multiplier=1.0, max_reward=max_reward)
        segment_rewards.append(reward)

    avg_reward = sum(segment_rewards) / max(1, len(segment_rewards))
    return avg_reward, segment_rewards


# =============================================================================
# Utilities
# =============================================================================

def worst_segments(
    targets: list[dict],
    segment_rewards: list[float],
    n: int = 3,
) -> list[dict]:
    """Return the N lowest-scoring target segments for focused logging."""
    paired = sorted(zip(segment_rewards, targets), key=lambda x: x[0])
    return [t for _, t in paired[:n]]
