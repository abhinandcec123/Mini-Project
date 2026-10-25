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


def score_donor(donor, request_lat, request_lng, max_distance_km=50):
    """Returns (score 0-100, distance_km) or (None, None) if disqualified."""
    if not donor.is_available or not donor.is_active:
        return None, None
    if not donor.is_eligible_now():
        return None, None

    distance = haversine_km(donor.latitude, donor.longitude, request_lat, request_lng)

    if distance is None or distance > max_distance_km:
        return None, distance
    # Fixed matching weights shown in AI Matches: availability 35%, distance 30%,
    # eligibility 20%, reliability 15%. Candidate filters make the first and third
    # components 100% for all returned donors.
    total = 35 + 30 * (1 - distance / max_distance_km) + 20 + 15 * (donor.reliability_score / 100)
    return round(total, 2), (round(distance, 2) if distance is not None else None)


def rank_donors_for_request(donors, blood_group, request_lat, request_lng, max_distance_km=50):
    compatible_groups = COMPATIBLE_DONORS.get(blood_group, [blood_group])
    ranked = []
    for donor in donors:
        if donor.blood_group not in compatible_groups:
            continue
        score, distance = score_donor(donor, request_lat, request_lng, max_distance_km)
        if score is None:
            continue
        ranked.append({"donor": donor, "score": score, "distance_km": distance})
    ranked.sort(key=lambda x: x["score"], reverse=True)
    return ranked
