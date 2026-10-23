from datetime import datetime
import math
from flask import Blueprint, request, jsonify
from extensions import db
from models import (
    Donor,
    RequestMatch,
    DonationCertificate,
    MAX_LOCATION_ACCURACY_METERS,
    log_action,
)
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
    return jsonify(donor.to_dict(include_contact=True, include_saved_pin=True)), 200


@donor_bp.put("/me")
@role_required("donor")
def update_profile():
    donor = _get_current_donor()
    if not donor:
        return jsonify({"error": "Donor not found"}), 404
    data = request.get_json(force=True)
    for field in ["full_name", "city", "gender"]:
        if field in data:
            setattr(donor, field, data[field])
    db.session.commit()
    return jsonify(donor.to_dict(include_saved_pin=True)), 200


@donor_bp.post("/availability")
@role_required("donor")
def toggle_availability():
    donor = _get_current_donor()
    if not donor:
        return jsonify({"error": "Donor not found"}), 404
    data = request.get_json(force=True)
    is_available = data.get("is_available", not donor.is_available)
    if not isinstance(is_available, bool):
        return jsonify({"error": "is_available must be a boolean"}), 400
    if is_available and not (
        donor.location_sharing_enabled
        and donor.gps_latitude is not None
        and donor.gps_longitude is not None
    ):
        return jsonify({"error": "Share your GPS location or choose a test pin before becoming available"}), 409

    donor.is_available = is_available
    if not is_available:
        donor.location_sharing_enabled = False
        donor.gps_latitude = None
        donor.gps_longitude = None
        donor.gps_accuracy_m = None
        donor.gps_location_source = None
    db.session.commit()
    return jsonify(donor.to_dict(include_saved_pin=True)), 200


@donor_bp.put("/location")
@role_required("donor")
def update_location():
    donor = _get_current_donor()
    if not donor:
        return jsonify({"error": "Donor not found"}), 404
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

    donor.gps_latitude = latitude
    donor.gps_longitude = longitude
    donor.gps_accuracy_m = accuracy_m
    donor.gps_location_source = "gps"
    donor.location_sharing_enabled = True
    db.session.commit()
    return jsonify(donor.to_dict(include_saved_pin=True)), 200


@donor_bp.put("/location/pin")
@role_required("donor")
def update_test_pin():
    donor = _get_current_donor()
    if not donor:
        return jsonify({"error": "Donor not found"}), 404
    data = request.get_json(force=True) or {}
    latitude = data.get("latitude")
    longitude = data.get("longitude")
    if (
        isinstance(latitude, bool)
        or not isinstance(latitude, (int, float))
        or not math.isfinite(latitude)
        or not -90 <= latitude <= 90
        or isinstance(longitude, bool)
        or not isinstance(longitude, (int, float))
        or not math.isfinite(longitude)
        or not -180 <= longitude <= 180
    ):
        return jsonify({"error": "Valid latitude and longitude are required"}), 400

    donor.gps_latitude = latitude
    donor.gps_longitude = longitude
    donor.gps_accuracy_m = 0
    donor.gps_location_source = "test_pin"
    donor.location_sharing_enabled = True
    db.session.commit()
    log_action("donor", donor.id, "updated_test_location_pin", "source=test_pin")
    return jsonify(donor.to_dict(include_saved_pin=True)), 200


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
    """Donation completion requires hospital approval before a certificate is issued."""
    donor_id = current_user_id()
    match = RequestMatch.query.filter_by(id=match_id, donor_id=donor_id).first()
    if not match:
        return jsonify({"error": "Request not found"}), 404
    if match.status == "completed":
        return jsonify({"error": "This donation has already been approved by the hospital."}), 400
    return jsonify({
        "error": "Hospital approval is required before a donation certificate can be issued."
    }), 400


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
