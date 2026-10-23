from datetime import datetime
import math

from flask import Blueprint, request, jsonify
from extensions import db
from models import (
    Hospital,
    Donor,
    BloodRequest,
    RequestMatch,
    DonationCertificate,
    BLOOD_GROUPS,
    MAX_LOCATION_ACCURACY_METERS,
    log_action,
)
from utils.security import role_required, current_user_id
from utils.ai_matching import rank_donors_for_request

hospital_bp = Blueprint("hospital", __name__, url_prefix="/api/hospital")


def _get_current_hospital():
    return Hospital.query.get(current_user_id())


def _approved_units(request_id):
    return (
        RequestMatch.query.filter_by(request_id=request_id, status="completed")
        .with_entities(RequestMatch.donor_id)
        .distinct()
        .count()
    )


@hospital_bp.get("/me")
@role_required("hospital")
def get_profile():
    hospital = _get_current_hospital()
    if not hospital:
        return jsonify({"error": "Hospital not found"}), 404
    return jsonify(hospital.to_dict()), 200


@hospital_bp.put("/location")
@role_required("hospital")
def update_location():
    hospital = _get_current_hospital()
    if not hospital:
        return jsonify({"error": "Hospital not found"}), 404
    data = request.get_json(force=True)
    latitude = data.get("latitude")
    longitude = data.get("longitude")
    accuracy_m = data.get("accuracy_m")
    if (
        isinstance(latitude, bool)
        or not isinstance(latitude, (int, float))
        or not math.isfinite(latitude)
        or not -90 <= latitude <= 90
        or isinstance(longitude, bool)
        or not isinstance(longitude, (int, float))
        or not math.isfinite(longitude)
        or not -180 <= longitude <= 180
        or isinstance(accuracy_m, bool)
        or not isinstance(accuracy_m, (int, float))
        or not math.isfinite(accuracy_m)
        or accuracy_m < 0
    ):
        return jsonify({"error": "Valid GPS coordinates and accuracy are required"}), 400
    if accuracy_m > MAX_LOCATION_ACCURACY_METERS:
        return jsonify({
            "error": f"Location accuracy must be {MAX_LOCATION_ACCURACY_METERS} meters or better. Try again outdoors."
        }), 400

    hospital.latitude = latitude
    hospital.longitude = longitude
    hospital.location_source = "device_gps"
    hospital.location_accuracy_km = accuracy_m / 1000
    hospital.gps_accuracy_m = accuracy_m
    db.session.commit()
    log_action("hospital", hospital.id, "updated_location")
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

    try:
        units_needed = int(data.get("units_needed", 1))
    except (TypeError, ValueError):
        return jsonify({"error": "units_needed must be a positive integer"}), 400
    if units_needed < 1:
        return jsonify({"error": "units_needed must be a positive integer"}), 400

    req = BloodRequest(
        hospital_id=hospital_id,
        patient_name=data["patient_name"].strip(),
        blood_group=data["blood_group"],
        units_needed=units_needed,
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
    max_distance = float(request.args.get("max_distance_km", 50))

    available_donors = Donor.query.filter_by(is_active=True, is_available=True).all()
    unavailable_donors = Donor.query.filter_by(is_active=True, is_available=False).all()

    ranked = rank_donors_for_request(
        available_donors,
        req.blood_group,
        hospital.effective_latitude,
        hospital.effective_longitude,
        max_distance,
    )
    fallback_ranked = rank_donors_for_request(
        unavailable_donors,
        req.blood_group,
        hospital.effective_latitude,
        hospital.effective_longitude,
        max_distance,
        include_unavailable=True,
    )

    already_matched_ids = {m.donor_id for m in req.matches}
    results = [
        {
            "donor": item["donor"].to_dict(include_contact=False),
            "score": item["score"],
            "distance_km": item["distance_km"],
            "already_dispatched": item["donor"].id in already_matched_ids,
        }
        for item in ranked + fallback_ranked
    ]
    return jsonify(results), 200


@hospital_bp.post("/requests/<int:request_id>/dispatch/<int:donor_id>")
@role_required("hospital")
def dispatch_to_donor(request_id, donor_id):
    """'Send Request to Donor' — creates a RequestMatch the donor can accept/decline."""
    hospital_id = current_user_id()
    req = BloodRequest.query.filter_by(id=request_id, hospital_id=hospital_id).first()
    if not req:
        return jsonify({"error": "Request not found"}), 404
    if req.status != "open":
        return jsonify({"error": "This blood request is no longer open"}), 409

    donor = Donor.query.get(donor_id)
    if not donor or not donor.is_active:
        return jsonify({"error": "Donor not found"}), 404

    existing = RequestMatch.query.filter_by(request_id=request_id, donor_id=donor_id).first()
    if existing:
        return jsonify({"error": "Already dispatched to this donor", "match": existing.to_dict()}), 409

    hospital = _get_current_hospital()
    from utils.ai_matching import score_donor

    score, distance = score_donor(
        donor,
        hospital.effective_latitude,
        hospital.effective_longitude,
        max_distance_km=10_000,
    )

    match = RequestMatch(request_id=request_id, donor_id=donor_id, match_score=score, distance_km=distance)
    db.session.add(match)
    db.session.commit()
    log_action("hospital", hospital_id, "dispatched_request", f"request_id={request_id}, donor_id={donor_id}")
    return jsonify(match.to_dict()), 201


@hospital_bp.get("/requests/<int:request_id>/matches")
@role_required("hospital")
def request_matches(request_id):
    hospital_id = current_user_id()
    req = BloodRequest.query.filter_by(id=request_id, hospital_id=hospital_id).first()
    if not req:
        return jsonify({"error": "Request not found"}), 404
    return jsonify([m.to_dict() for m in req.matches]), 200


@hospital_bp.post("/requests/<int:request_id>/matches/<int:match_id>/confirm")
@role_required("hospital")
def confirm_donation(request_id, match_id):
    hospital_id = current_user_id()
    req = (
        BloodRequest.query.filter_by(id=request_id, hospital_id=hospital_id)
        .with_for_update()
        .first()
    )
    if not req:
        return jsonify({"error": "Request not found"}), 404

    match = RequestMatch.query.filter_by(id=match_id, request_id=request_id).first()
    if not match:
        return jsonify({"error": "Match not found"}), 404
    if req.status != "open":
        return jsonify({"error": "This blood request is no longer open"}), 409
    if match.status != "accepted":
        return jsonify({"error": "Only accepted donations can be confirmed by the hospital"}), 400

    existing_certificate = DonationCertificate.query.filter_by(match_id=match.id).first()
    if existing_certificate:
        return jsonify({"error": "Certificate already exists for this donation", "certificate": existing_certificate.to_dict()}), 409

    donor = Donor.query.filter_by(id=match.donor_id).with_for_update().first()
    if not donor:
        return jsonify({"error": "Matched donor not found"}), 404
    if not donor.is_eligible_now():
        return jsonify({
            "error": "This donor is not yet eligible to donate again. The 90-day interval must pass first."
        }), 409

    approved_donations = _approved_units(request_id)
    if approved_donations >= req.units_needed:
        return jsonify({"error": "This request already has enough approved donations"}), 409

    match.status = "completed"
    req.status = (
        "fulfilled"
        if approved_donations + 1 >= req.units_needed
        else "open"
    )
    donor.last_donation_date = datetime.utcnow()
    donor.total_donations = (donor.total_donations or 0) + 1
    donor.reliability_score = min(100, donor.reliability_score + 2)

    cert = DonationCertificate(
        donor_id=donor.id,
        match_id=match.id,
        hospital_name=req.hospital.name if req.hospital else "LifePulse Network",
        units_donated=1,
    )
    db.session.add(cert)
    db.session.commit()
    log_action("hospital", hospital_id, "approved_donation", f"request_id={request_id}, match_id={match_id}")
    return jsonify({
        "match": match.to_dict(),
        "certificate": cert.to_dict(),
        "request": req.to_dict(),
        "approved_units": approved_donations + 1,
        "units_needed": req.units_needed,
    }), 200


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
    approved_donations = _approved_units(request_id)
    if approved_donations < req.units_needed:
        return jsonify({
            "error": f"Approve donations from {req.units_needed - approved_donations} more distinct donor(s) before fulfilling this request."
        }), 409
    req.status = "fulfilled"
    db.session.commit()
    log_action("hospital", hospital_id, "fulfilled_request", f"request_id={request_id}")
    return jsonify(req.to_dict()), 200
