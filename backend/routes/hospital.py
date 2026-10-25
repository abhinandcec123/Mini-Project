from datetime import datetime, timedelta
from flask import Blueprint, request, jsonify
from extensions import db
from models import Hospital, Donor, BloodRequest, RequestMatch, BLOOD_GROUPS, log_action
from utils.security import role_required, current_user_id
from utils.ai_matching import rank_donors_for_request

hospital_bp = Blueprint("hospital", __name__, url_prefix="/api/hospital")


def _get_current_hospital():
    return Hospital.query.get(current_user_id())


@hospital_bp.get("/me")
@role_required("hospital")
def get_profile():
    hospital = _get_current_hospital()
    if not hospital:
        return jsonify({"error": "Hospital not found"}), 404
    return jsonify(hospital.to_dict()), 200


@hospital_bp.post("/requests")
@role_required("hospital")
def create_request():
    hospital_id = current_user_id()
    data = request.get_json(force=True)

    if data.get("blood_group") not in BLOOD_GROUPS:
        return jsonify({"error": "Invalid blood group"}), 400
    if not data.get("patient_name"):
        return jsonify({"error": "Patient name is required"}), 400

    req = BloodRequest(
        hospital_id=hospital_id,
        patient_name=data["patient_name"].strip(),
        blood_group=data["blood_group"],
        units_needed=int(data.get("units_needed", 1)),
        priority=data.get("priority", "normal"),
        notes=data.get("notes"),
    )
    db.session.add(req)
    db.session.commit()
    log_action("hospital", hospital_id, "created_request", f"request_id={req.id}")
    return jsonify(req.to_dict()), 201


@hospital_bp.get("/requests")
@role_required("hospital")
def list_requests():
    hospital_id = current_user_id()
    priority = request.args.get("priority")
    status = request.args.get("status")

    query = BloodRequest.query.filter_by(hospital_id=hospital_id)
    if priority:
        query = query.filter_by(priority=priority)
    if status:
        query = query.filter_by(status=status)

    reqs = query.order_by(BloodRequest.created_at.desc()).all()
    return jsonify([r.to_dict() for r in reqs]), 200


@hospital_bp.get("/requests/<int:request_id>/candidates")
@role_required("hospital")
def ai_candidates(request_id):
    """The AI donor ranking view: returns donors sorted by match score."""
    hospital_id = current_user_id()
    req = BloodRequest.query.filter_by(id=request_id, hospital_id=hospital_id).first()
    if not req:
        return jsonify({"error": "Request not found"}), 404

    hospital = _get_current_hospital()
    try:
        max_distance = float(request.args.get("max_distance_km", 50))
    except (TypeError, ValueError):
        return jsonify({"error": "Radius must be between 5 and 50 km"}), 400
    max_distance = max(5, min(50, max_distance))

    donors = Donor.query.filter_by(is_active=True, is_available=True).all()
    ranked = rank_donors_for_request(
        donors, req.blood_group, hospital.latitude, hospital.longitude, max_distance
    )
    if req.priority == "critical":
        ranked.sort(key=lambda item: item["distance_km"] if item["distance_km"] is not None else float("inf"))

    already_matched_ids = {m.donor_id for m in req.matches}
    matches_by_donor = {m.donor_id: m for m in req.matches}
    results = [
        {
            "donor": item["donor"].to_dict(include_contact=False),
            "score": item["score"],
            "distance_km": item["distance_km"],
            "already_dispatched": item["donor"].id in already_matched_ids,
            "match_status": matches_by_donor[item["donor"].id].status if item["donor"].id in matches_by_donor else None,
        }
        for item in ranked
    ]
    ranked_ids = {item["donor"].id for item in ranked}
    for match in req.matches:
        if match.donor_id not in ranked_ids and match.donor:
            results.append({
                "donor": match.donor.to_dict(include_contact=False),
                "score": match.match_score or 0,
                "distance_km": match.distance_km,
                "already_dispatched": True,
                "match_status": match.status,
            })
    return jsonify(results), 200


@hospital_bp.post("/requests/<int:request_id>/dispatch-ranked")
@role_required("hospital")
def dispatch_ranked(request_id):
    """Broadcast one request to every eligible, available donor inside its radius."""
    hospital_id = current_user_id()
    req = BloodRequest.query.filter_by(id=request_id, hospital_id=hospital_id).first()
    if not req:
        return jsonify({"error": "Request not found"}), 404
    if req.status != "open":
        return jsonify({"error": "This request is no longer open"}), 409
    try:
        radius = float((request.get_json(silent=True) or {}).get("max_distance_km", 50))
    except (TypeError, ValueError):
        return jsonify({"error": "Radius must be between 5 and 50 km"}), 400
    if not 5 <= radius <= 50:
        return jsonify({"error": "Radius must be between 5 and 50 km"}), 400

    hospital = _get_current_hospital()
    donors = Donor.query.filter_by(is_active=True, is_available=True).all()
    ranked = rank_donors_for_request(
        donors, req.blood_group, hospital.latitude, hospital.longitude, radius
    )
    if req.priority == "critical":
        ranked.sort(key=lambda item: item["distance_km"] if item["distance_km"] is not None else float("inf"))
    existing_ids = {m.donor_id for m in req.matches}
    commitment_cutoff = datetime.utcnow() - timedelta(days=90)
    busy_ids = {
        donor_id for (donor_id,) in db.session.query(RequestMatch.donor_id)
        .filter(
            RequestMatch.status.in_(["accepted", "completed"]),
            RequestMatch.responded_at >= commitment_cutoff,
        ).all()
    }
    dispatched = []
    for item in ranked:
        donor = item["donor"]
        if donor.id in existing_ids or donor.id in busy_ids or item["distance_km"] is None:
            continue
        match = RequestMatch(
            request_id=req.id, donor_id=donor.id,
            match_score=item["score"], distance_km=item["distance_km"],
        )
        db.session.add(match)
        dispatched.append(match)
    db.session.commit()
    log_action("hospital", hospital_id, "broadcast_request",
               f"request_id={request_id}, radius_km={radius}, donor_count={len(dispatched)}")
    return jsonify({"dispatched_count": len(dispatched), "radius_km": radius}), 201


@hospital_bp.get("/requests/<int:request_id>/matches")
@role_required("hospital")
def request_matches(request_id):
    hospital_id = current_user_id()
    req = BloodRequest.query.filter_by(id=request_id, hospital_id=hospital_id).first()
    if not req:
        return jsonify({"error": "Request not found"}), 404
    return jsonify([m.to_dict() for m in req.matches]), 200


@hospital_bp.post("/requests/<int:request_id>/cancel")
@role_required("hospital")
def cancel_request(request_id):
    hospital_id = current_user_id()
    req = BloodRequest.query.filter_by(id=request_id, hospital_id=hospital_id).first()
    if not req:
        return jsonify({"error": "Request not found"}), 404
    req.status = "cancelled"
    db.session.commit()
    log_action("hospital", hospital_id, "cancelled_request", f"request_id={request_id}")
    return jsonify(req.to_dict()), 200


@hospital_bp.post("/requests/<int:request_id>/fulfill")
@role_required("hospital")
def fulfill_request(request_id):
    hospital_id = current_user_id()
    req = BloodRequest.query.filter_by(id=request_id, hospital_id=hospital_id).first()
    if not req:
        return jsonify({"error": "Request not found"}), 404
    req.status = "fulfilled"
    db.session.commit()
    log_action("hospital", hospital_id, "fulfilled_request", f"request_id={request_id}")
    return jsonify(req.to_dict()), 200
