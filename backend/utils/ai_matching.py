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

    # Emergency matching uses the same opted-in, available live location shown
    # on the admin map (including explicitly saved test pins).
    if not donor.is_available or not donor.location_sharing_enabled:
        return None, None
    donor_lat = donor.gps_latitude
    donor_lng = donor.gps_longitude
    if donor_lat is None or donor_lng is None:
        return None, None
    distance = haversine_km(donor_lat, donor_lng, request_lat, request_lng)

    if distance is None:
        distance_factor = 0.5
    elif distance > max_distance_km:
        return None, distance
    else:
        distance_factor = 1 - (distance / max_distance_km)

    # Keep this score aligned with the hospital recommendation card.
    availability_score = 35 if donor.is_available else 0
    distance_score = 30 * distance_factor
    eligibility_score = 20
    reliability_score = 15 * (donor.reliability_score / 100)
    total = availability_score + distance_score + eligibility_score + reliability_score
    return round(total, 2), (round(distance, 4) if distance is not None else None)


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
