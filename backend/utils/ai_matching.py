"""Donor ranking 'AI' scoring engine.

Not a machine-learning model — a transparent weighted-scoring function,
which is what the original handover doc described as "AI donor ranking".
Weights: distance, reliability, eligibility, availability.
"""
import math
from models import COMPATIBLE_DONORS


def haversine_km(lat1, lon1, lat2, lon2):
    if None in (lat1, lon1, lat2, lon2):
        return None
    R = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlambda / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def score_donor(donor, request_lat, request_lng, max_distance_km=50, include_unavailable=False):
    """Returns (score 0-100, distance_km) or (None, None) if disqualified."""
    if not donor.is_active:
        return None, None
    if not donor.is_available and not include_unavailable:
        return None, None
    if not donor.is_eligible_now():
        return None, None

    distance = haversine_km(donor.latitude, donor.longitude, request_lat, request_lng)

    # Distance sub-score (40 pts): closer is better, capped at max_distance_km
    if distance is None:
        distance_score = 20  # unknown location: neutral-low score
    elif distance > max_distance_km:
        return None, distance
    else:
        distance_score = 40 * (1 - (distance / max_distance_km))

    # Reliability sub-score (30 pts): donor's historical reliability_score is 0-100
    reliability_score = 30 * (donor.reliability_score / 100)

    # Eligibility sub-score (20 pts): full points since is_eligible_now already filtered
    eligibility_score = 20

    # Availability / experience sub-score (10 pts): rewards donors with a donation history
    experience_score = min(10, donor.total_donations * 2)

    total = distance_score + reliability_score + eligibility_score + experience_score
    return round(total, 2), (round(distance, 2) if distance is not None else None)


def rank_donors_for_request(donors, blood_group, request_lat, request_lng, max_distance_km=50, include_unavailable=False):
    compatible_groups = COMPATIBLE_DONORS.get(blood_group, [blood_group])
    ranked = []
    for donor in donors:
        if donor.blood_group not in compatible_groups:
            continue
        score, distance = score_donor(
            donor,
            request_lat,
            request_lng,
            max_distance_km,
            include_unavailable=include_unavailable,
        )
        if score is None:
            continue
        ranked.append({"donor": donor, "score": score, "distance_km": distance})
    ranked.sort(key=lambda x: x["score"], reverse=True)
    return ranked
