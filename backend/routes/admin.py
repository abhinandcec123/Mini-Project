from flask import Blueprint, request, jsonify
from extensions import db
from models import (
    Donor,
    Hospital,
    BloodRequest,
    DonationCertificate,
    AuditLog,
    log_action,
)
from utils.security import role_required, current_user_id

admin_bp = Blueprint("admin", __name__, url_prefix="/api/admin")


@admin_bp.get("/donors")
@role_required("admin")
def list_donors():
    donors = Donor.query.order_by(Donor.created_at.desc()).all()
    return jsonify([d.to_dict() for d in donors]), 200


@admin_bp.get("/hospitals")
@role_required("admin")
def list_hospitals():
    hospitals = Hospital.query.order_by(Hospital.created_at.desc()).all()
    return jsonify([h.to_dict() for h in hospitals]), 200


@admin_bp.post("/hospitals/<int:hospital_id>/verify")
@role_required("admin")
def verify_hospital(hospital_id):
    hospital = Hospital.query.get(hospital_id)
    if not hospital:
        return jsonify({"error": "Hospital not found"}), 404
    hospital.is_verified = True
    db.session.commit()
    log_action("admin", current_user_id(), "verified_hospital", f"hospital_id={hospital_id}")
    return jsonify(hospital.to_dict()), 200


@admin_bp.delete("/donors/<int:donor_id>")
@role_required("admin")
def remove_donor(donor_id):
    donor = Donor.query.get(donor_id)
    if not donor:
        return jsonify({"error": "Donor not found"}), 404
    donor.is_active = False  # soft delete: preserves donation history & audit trail
    db.session.commit()
    log_action("admin", current_user_id(), "removed_donor", f"donor_id={donor_id}")
    return jsonify({"message": "Donor removed"}), 200


@admin_bp.delete("/hospitals/<int:hospital_id>")
@role_required("admin")
def remove_hospital(hospital_id):
    hospital = Hospital.query.get(hospital_id)
    if not hospital:
        return jsonify({"error": "Hospital not found"}), 404
    hospital.is_active = False
    db.session.commit()
    log_action("admin", current_user_id(), "removed_hospital", f"hospital_id={hospital_id}")
    return jsonify({"message": "Hospital removed"}), 200


@admin_bp.get("/audit-logs")
@role_required("admin")
def audit_logs():
    logs = AuditLog.query.order_by(AuditLog.created_at.desc()).limit(200).all()
    return jsonify([l.to_dict() for l in logs]), 200


@admin_bp.get("/donor-locations")
@role_required("admin")
def donor_locations():
    """Return registered coordinates for active donors, without contact data."""
    donors = (
        Donor.query.filter(
            Donor.is_active.is_(True),
            Donor.latitude.isnot(None),
            Donor.longitude.isnot(None),
        )
        .order_by(Donor.full_name.asc())
        .all()
    )
    locations = []
    for donor in donors:
        location = donor.to_dict(include_contact=False)
        location["location_source"] = "registered"
        locations.append(location)
    return jsonify(locations), 200


@admin_bp.get("/fulfilled-donations")
@role_required("admin")
def fulfilled_donations():
    """Return donation certificates and coordinates of donors who completed."""
    certificates = (
        DonationCertificate.query.order_by(
            DonationCertificate.donation_date.desc()
        ).all()
    )
    donations = []
    donors_by_id = {}
    for certificate in certificates:
        donation = certificate.to_dict()
        donor = certificate.donor
        if donor:
            donation["blood_group"] = donor.blood_group
            if donor.is_active:
                donors_by_id[donor.id] = donor
        else:
            donation["blood_group"] = None
        donations.append(donation)

    completed_donor_locations = []
    for donor in donors_by_id.values():
        if donor.latitude is None or donor.longitude is None:
            continue
        location = donor.to_dict(include_contact=False)
        location["location_source"] = "registered"
        completed_donor_locations.append(location)

    return jsonify({
        "total_completed_donations": len(donations),
        "completed_donations": donations,
        "completed_donor_locations": completed_donor_locations,
    }), 200


@admin_bp.get("/inventory")
@role_required("admin")
def inventory_overview():
    """Aggregate reserve view: available eligible donor counts per blood group."""
    donors = Donor.query.filter_by(is_active=True, is_available=True).all()
    counts = {}
    for d in donors:
        if d.is_eligible_now():
            counts[d.blood_group] = counts.get(d.blood_group, 0) + 1
    return jsonify(counts), 200


@admin_bp.get("/stats")
@role_required("admin")
def dashboard_stats():
    return jsonify({
        "total_donors": Donor.query.filter_by(is_active=True).count(),
        "total_hospitals": Hospital.query.filter_by(is_active=True).count(),
        "open_requests": BloodRequest.query.filter_by(status="open").count(),
        "fulfilled_requests": BloodRequest.query.filter_by(status="fulfilled").count(),
    }), 200
