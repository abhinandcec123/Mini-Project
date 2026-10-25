"""Rank live donor pins and manage dispatch offer expiration."""

from datetime import datetime, timedelta
from extensions import db
from models import Donor, RequestMatch
from utils.ai_matching import rank_donors_for_request


def ranked_request_candidates(blood_request, hospital, max_distance_km=50):
    origin_lat = hospital.latitude if hospital.latitude is not None else hospital.fallback_latitude
    origin_lng = hospital.longitude if hospital.longitude is not None else hospital.fallback_longitude
    if origin_lat is None or origin_lng is None:
        return []
    radius = max(5, min(float(max_distance_km), 50))
    donors = Donor.query.filter_by(
        is_active=True, is_available=True, location_sharing_enabled=True
    ).filter(Donor.gps_latitude.isnot(None), Donor.gps_longitude.isnot(None)).all()
    ranked = rank_donors_for_request(
        donors,
        blood_request.blood_group,
        origin_lat,
        origin_lng,
        radius,
        include_unavailable=False,
    )

    # A donor with an accepted or completed, not-yet-approved match is already
    # committed to a donation and cannot be offered another one.
    busy_ids = {
        row[0]
        for row in db.session.query(RequestMatch.donor_id)
        .filter(RequestMatch.status.in_(("accepted", "completed")))
        .filter(RequestMatch.request_id != blood_request.id)
        .distinct()
        .all()
    }
    ranked = [entry for entry in ranked if entry["donor"].id not in busy_ids]
    ranked.sort(key=lambda entry: (
        -entry["score"],
        entry["distance_km"] if entry["distance_km"] is not None else float("inf"),
    ))
    return ranked


def advance_ranked_queues(request_ids):
    """Keep the selected ten-offer batch bounded after donor responses."""
    # Hospitals select the radius and dispatch a batch explicitly. Automatically
    # extending the batch here could contact donors outside that chosen radius.
    return None


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
