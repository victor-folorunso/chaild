from rapidfuzz.distance import Levenshtein # pyright: ignore[reportMissingImports]

def compute_char_similarity(pred_text, target_text):
    """0-1 similarity based on character-level Levenshtein."""
    pred_text = pred_text.lower().strip()
    target_text = target_text.lower().strip()
    max_len = max(len(pred_text), len(target_text))
    if max_len == 0:
        return 1.0
    distance = Levenshtein.distance(pred_text, target_text)
    return max(0.0, (max_len - distance) / max_len)

def score_segment(pred_text, target_text, is_silence, duration, max_reward=10.0):
    """
    Returns reward for a segment.
    - Silence: penalize if output exists, scaled by duration
    - Word: partial credit based on character similarity
    """
    if is_silence:
        violation = len(pred_text.strip())
        penalty_factor = min(1.0, violation / max(1, len(target_text)))
        return max_reward * max(0.0, 1.0 - penalty_factor)
    else:
        return max_reward * compute_char_similarity(pred_text, target_text)

def score_full_video(predictions, targets):
    """
    Full-video scoring:
    predictions: list of {"start", "stop", "pred_text"}
    targets: list of {"start", "stop", "text"}
    Returns aggregate reward and optionally per-segment score list.
    """
    total_reward = 0.0
    segment_rewards = []
    for seg_pred, seg_target in zip(predictions, targets):
        is_silence = seg_target["text"].upper() == "SILENCE"
        duration = seg_target["stop"] - seg_target["start"]
        reward = score_segment(seg_pred["pred_text"], seg_target["text"], is_silence, duration)
        segment_rewards.append(reward)
        total_reward += reward
    average_reward = total_reward / max(1, len(segment_rewards))
    return average_reward, segment_rewards