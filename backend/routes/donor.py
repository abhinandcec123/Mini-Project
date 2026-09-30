from datetime import datetime
from flask import Blueprint, request, jsonify
from extensions import db
from models import Donor, RequestMatch, DonationCertificate, log_action
from utils.security import role_required, current_user_id

donor_bp = Blueprint("donor", __name__, url_prefix="/api/donor")


def _get_current_donor():
    return Donor.query.get(current_user_id())


@donor_bp.get("/me")
@role_required("donor")
def get_profile():
    donor = _get_current_donor()
    if not donor:
        return jsonify({"error": "Donor not found"}), 404
    return jsonify(donor.to_dict()), 200


@donor_bp.put("/me")
@role_required("donor")
def update_profile():
    donor = _get_current_donor()
    if not donor:
        return jsonify({"error": "Donor not found"}), 404
    data = request.get_json(force=True)
    for field in ["full_name", "city", "gender", "latitude", "longitude"]:
        if field in data:
            setattr(donor, field, data[field])
    db.session.commit()
    return jsonify(donor.to_dict()), 200


@donor_bp.post("/availability")
@role_required("donor")
def toggle_availability():
    donor = _get_current_donor()
    if not donor:
        return jsonify({"error": "Donor not found"}), 404
    data = request.get_json(force=True)
    donor.is_available = bool(data.get("is_available", not donor.is_available))
    db.session.commit()
    return jsonify(donor.to_dict()), 200


@donor_bp.get("/requests")
@role_required("donor")
def incoming_requests():
    """All emergency requests dispatched to this donor, newest first."""
    donor_id = current_user_id()
    matches = (
        RequestMatch.query.filter_by(donor_id=donor_id)
        .order_by(RequestMatch.dispatched_at.desc())
        .all()
    )
    return jsonify([m.to_dict() for m in matches]), 200


@donor_bp.post("/requests/<int:match_id>/accept")
@role_required("donor")
def accept_request(match_id):
    donor_id = current_user_id()
    match = RequestMatch.query.filter_by(id=match_id, donor_id=donor_id).first()
    if not match:
        return jsonify({"error": "Request not found"}), 404
    if match.status != "pending":
        return jsonify({"error": f"This request was already {match.status}"}), 400

    match.status = "accepted"
    match.responded_at = datetime.utcnow()
    db.session.commit()
    log_action("donor", donor_id, "accepted_request", f"match_id={match_id}")
    return jsonify(match.to_dict()), 200


@donor_bp.post("/requests/<int:match_id>/decline")
@role_required("donor")
def decline_request(match_id):
    donor_id = current_user_id()
    match = RequestMatch.query.filter_by(id=match_id, donor_id=donor_id).first()
    if not match:
        return jsonify({"error": "Request not found"}), 404
    if match.status != "pending":
        return jsonify({"error": f"This request was already {match.status}"}), 400

    match.status = "declined"
    match.responded_at = datetime.utcnow()
    db.session.commit()
    log_action("donor", donor_id, "declined_request", f"match_id={match_id}")
    return jsonify(match.to_dict()), 200


@donor_bp.post("/requests/<int:match_id>/complete")
@role_required("donor")
def complete_donation(match_id):
    """Marks a donation as fulfilled and issues a certificate."""
    donor_id = current_user_id()
    match = RequestMatch.query.filter_by(id=match_id, donor_id=donor_id).first()
    if not match:
        return jsonify({"error": "Request not found"}), 404
    if match.status != "accepted":
        return jsonify({"error": "Only an accepted request can be marked complete"}), 400

    match.status = "completed"
    donor = _get_current_donor()
    donor.last_donation_date = datetime.utcnow()
    donor.total_donations = (donor.total_donations or 0) + 1
    donor.reliability_score = min(100, donor.reliability_score + 2)

    cert = DonationCertificate(
        donor_id=donor.id,
        match_id=match.id,
        hospital_name=match.request.hospital.name if match.request and match.request.hospital else "LifePulse Network",
        units_donated=1,
    )
    db.session.add(cert)
    db.session.commit()
    log_action("donor", donor_id, "completed_donation", f"match_id={match_id}")
    return jsonify({"match": match.to_dict(), "certificate": cert.to_dict()}), 200


@donor_bp.get("/certificates")
@role_required("donor")
def my_certificates():
    donor_id = current_user_id()
    certs = (
        DonationCertificate.query.filter_by(donor_id=donor_id)
        .order_by(DonationCertificate.donation_date.desc())
        .all()
    )
    return jsonify([c.to_dict() for c in certs]), 200
