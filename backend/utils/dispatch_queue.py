"""One-at-a-time ranked dispatch helpers for hospital blood requests."""

from datetime import datetime, timedelta
import math

from extensions import db
from models import BloodRequest, Donor, RequestMatch
from utils.ai_matching import rank_donors_for_request


def ranked_request_candidates(blood_request, hospital, max_distance_km=50):
    origin_lat = hospital.latitude if hospital.latitude is not None else hospital.fallback_latitude
    origin_lng = hospital.longitude if hospital.longitude is not None else hospital.fallback_longitude
    radius = 20_100 if blood_request.priority == "critical" else max_distance_km
    donors = Donor.query.filter_by(is_active=True).all()
    ranked = rank_donors_for_request(
        donors,
        blood_request.blood_group,
        origin_lat,
        origin_lng,
        radius,
        include_unavailable=True,
    )

    # A donor with an accepted or completed, not-yet-approved match is already
    # committed to a donation and cannot be offered another one.
    busy_ids = {
        row[0]
        for row in db.session.query(RequestMatch.donor_id)
        .filter(RequestMatch.status.in_(("accepted", "completed")))
        .distinct()
        .all()
    }
    ranked = [entry for entry in ranked if entry["donor"].id not in busy_ids]
    if blood_request.priority == "critical":
        for entry in ranked:
            distance = entry["distance_km"]
            donor = entry["donor"]
            distance_score = (
                15 if distance is None
                else 30 * math.exp(-distance / 100)
            )
            entry["score"] = round(
                (35 if donor.is_available else 0)
                + distance_score
                + 20
                + 15 * (donor.reliability_score / 100),
                2,
            )
        ranked.sort(key=lambda entry: (
            entry["distance_km"] is None,
            entry["distance_km"] if entry["distance_km"] is not None else float("inf"),
            not entry["donor"].is_available,
            -entry["score"],
        ))
    else:
        ranked.sort(key=lambda entry: (
            not entry["donor"].is_available,
            -entry["score"],
            entry["distance_km"] if entry["distance_km"] is not None else float("inf"),
        ))
    return ranked


def dispatch_next_candidate(blood_request, hospital):
    """Create at most one pending dispatch for the next ranked donor."""
    locked_request = (
        BloodRequest.query.filter_by(id=blood_request.id).with_for_update().first()
    )
    if not locked_request or locked_request.status != "open":
        return None

    blood_request = locked_request
    matches = RequestMatch.query.filter_by(request_id=blood_request.id).all()
    if any(match.status == "pending" for match in matches):
        return None
    occupied_units = sum(match.status in ("accepted", "completed") for match in matches)
    if occupied_units >= blood_request.units_needed:
        return None

    already_contacted = {match.donor_id for match in matches}
    for entry in ranked_request_candidates(blood_request, hospital):
        donor = entry["donor"]
        if donor.id in already_contacted:
            continue
        match = RequestMatch(
            request_id=blood_request.id,
            donor_id=donor.id,
            match_score=entry["score"],
            distance_km=entry["distance_km"],
            status="pending",
            dispatched_at=datetime.utcnow(),
        )
        db.session.add(match)
        db.session.commit()
        return match
    return None


def advance_ranked_queues(request_ids):
    """Continue each affected open request after a donor response."""
    for request_id in set(request_ids):
        blood_request = db.session.get(BloodRequest, request_id)
        if blood_request and blood_request.status == "open" and blood_request.hospital:
            dispatch_next_candidate(blood_request, blood_request.hospital)


def expire_stale_dispatches(request_id=None, donor_id=None):
    """Release unanswered dispatches and continue their ranked queues."""
    query = RequestMatch.query.filter_by(status="pending")
    if request_id is not None:
        query = query.filter_by(request_id=request_id)
    if donor_id is not None:
        query = query.filter_by(donor_id=donor_id)

    now = datetime.utcnow()
    advanced = set()
    expired = False
    for match in query.all():
        timeout = timedelta(minutes=4 if match.request.priority == "critical" else 6)
        dispatched_at = match.dispatched_at or now
        if now - dispatched_at >= timeout:
            match.status = "declined"
            match.responded_at = now
            advanced.add(match.request_id)
            expired = True
    if expired:
        db.session.commit()
        advance_ranked_queues(advanced)
