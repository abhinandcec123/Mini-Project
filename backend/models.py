from datetime import datetime
from extensions import db

BLOOD_GROUPS = ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"]

COMPATIBLE_DONORS = {
    "A+": ["A+", "A-", "O+", "O-"],
    "A-": ["A-", "O-"],
    "B+": ["B+", "B-", "O+", "O-"],
    "B-": ["B-", "O-"],
    "AB+": ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"],
    "AB-": ["A-", "B-", "AB-", "O-"],
    "O+": ["O+", "O-"],
    "O-": ["O-"],
}


def normalize_phone(phone: str) -> str:
    """Strip spaces/dashes and enforce a single canonical phone format."""
    digits = "".join(ch for ch in phone if ch.isdigit())
    return digits[-10:] if len(digits) >= 10 else digits


class Donor(db.Model):
    __tablename__ = "donors"

    id = db.Column(db.Integer, primary_key=True)
    full_name = db.Column(db.String(120), nullable=False)
    phone = db.Column(db.String(15), unique=True, nullable=False, index=True)
    email = db.Column(db.String(120), unique=True, nullable=True)
    password_hash = db.Column(db.String(255), nullable=False)

    blood_group = db.Column(db.String(3), nullable=False)
    age = db.Column(db.Integer, nullable=False)
    gender = db.Column(db.String(20), nullable=True)

    address = db.Column(db.String(255), nullable=True)
    latitude = db.Column(db.Float, nullable=True)
    longitude = db.Column(db.Float, nullable=True)
    city = db.Column(db.String(100), nullable=True)

    is_available = db.Column(db.Boolean, default=True)
    reliability_score = db.Column(db.Float, default=80.0)  # 0-100, adjusted by history
    total_donations = db.Column(db.Integer, default=0)
    last_donation_date = db.Column(db.DateTime, nullable=True)

    is_active = db.Column(db.Boolean, default=True)  # soft-delete flag for admin removal
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def is_eligible_now(self):
        """A donor must wait ~90 days between whole-blood donations."""
        if not self.last_donation_date:
            return True
        return (datetime.utcnow() - self.last_donation_date).days >= 90

    def to_dict(self, include_contact=True):
        data = {
            "id": self.id,
            "full_name": self.full_name,
            "blood_group": self.blood_group,
            "age": self.age,
            "gender": self.gender,
            "city": self.city,
            "latitude": self.latitude,
            "longitude": self.longitude,
            "is_available": self.is_available,
            "reliability_score": self.reliability_score,
            "total_donations": self.total_donations,
            "is_eligible_now": self.is_eligible_now(),
            "last_donation_date": self.last_donation_date.isoformat() if self.last_donation_date else None,
        }
        if include_contact:
            data["phone"] = self.phone
            data["email"] = self.email
        return data


class Hospital(db.Model):
    __tablename__ = "hospitals"

    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(150), nullable=False)
    registration_number = db.Column(db.String(80), unique=True, nullable=False)
    phone = db.Column(db.String(15), unique=True, nullable=False, index=True)
    email = db.Column(db.String(120), unique=True, nullable=True)
    password_hash = db.Column(db.String(255), nullable=False)

    address = db.Column(db.String(255), nullable=True)
    city = db.Column(db.String(100), nullable=True)
    latitude = db.Column(db.Float, nullable=True)
    longitude = db.Column(db.Float, nullable=True)

    is_verified = db.Column(db.Boolean, default=False)
    is_active = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "registration_number": self.registration_number,
            "phone": self.phone,
            "email": self.email,
            "address": self.address,
            "city": self.city,
            "latitude": self.latitude,
            "longitude": self.longitude,
            "is_verified": self.is_verified,
            "is_active": self.is_active,
        }


class Admin(db.Model):
    __tablename__ = "admins"

    id = db.Column(db.Integer, primary_key=True)
    full_name = db.Column(db.String(120), nullable=False)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(255), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {"id": self.id, "full_name": self.full_name, "email": self.email}


class BloodRequest(db.Model):
    __tablename__ = "blood_requests"

    id = db.Column(db.Integer, primary_key=True)
    hospital_id = db.Column(db.Integer, db.ForeignKey("hospitals.id"), nullable=False)

    patient_name = db.Column(db.String(120), nullable=False)
    blood_group = db.Column(db.String(3), nullable=False)
    units_needed = db.Column(db.Integer, default=1)
    priority = db.Column(db.String(20), default="normal")  # critical, urgent, normal
    notes = db.Column(db.String(500), nullable=True)

    status = db.Column(db.String(20), default="open")  # open, fulfilled, cancelled
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    hospital = db.relationship("Hospital", backref="requests")

    def to_dict(self):
        return {
            "id": self.id,
            "hospital_id": self.hospital_id,
            "hospital_name": self.hospital.name if self.hospital else None,
            "hospital_city": self.hospital.city if self.hospital else None,
            "patient_name": self.patient_name,
            "blood_group": self.blood_group,
            "units_needed": self.units_needed,
            "priority": self.priority,
            "notes": self.notes,
            "status": self.status,
            "created_at": self.created_at.isoformat(),
        }


class RequestMatch(db.Model):
    """Represents a dispatched request sent to a specific donor, and their response."""

    __tablename__ = "request_matches"

    id = db.Column(db.Integer, primary_key=True)
    request_id = db.Column(db.Integer, db.ForeignKey("blood_requests.id"), nullable=False)
    donor_id = db.Column(db.Integer, db.ForeignKey("donors.id"), nullable=False)

    match_score = db.Column(db.Float, nullable=True)
    distance_km = db.Column(db.Float, nullable=True)

    status = db.Column(db.String(20), default="pending")  # pending, accepted, declined, completed
    dispatched_at = db.Column(db.DateTime, default=datetime.utcnow)
    responded_at = db.Column(db.DateTime, nullable=True)

    request = db.relationship("BloodRequest", backref="matches")
    donor = db.relationship("Donor", backref="incoming_matches")

    def to_dict(self):
        return {
            "id": self.id,
            "request": self.request.to_dict() if self.request else None,
            "donor": self.donor.to_dict(include_contact=False) if self.donor else None,
            "donor_id": self.donor_id,
            "match_score": self.match_score,
            "distance_km": self.distance_km,
            "status": self.status,
            "dispatched_at": self.dispatched_at.isoformat(),
            "responded_at": self.responded_at.isoformat() if self.responded_at else None,
        }


class DonationCertificate(db.Model):
    __tablename__ = "donation_certificates"

    id = db.Column(db.Integer, primary_key=True)
    donor_id = db.Column(db.Integer, db.ForeignKey("donors.id"), nullable=False)
    match_id = db.Column(db.Integer, db.ForeignKey("request_matches.id"), nullable=True)
    hospital_name = db.Column(db.String(150), nullable=False)
    donation_date = db.Column(db.DateTime, default=datetime.utcnow)
    units_donated = db.Column(db.Integer, default=1)

    donor = db.relationship("Donor", backref="certificates")

    def to_dict(self):
        return {
            "id": self.id,
            "donor_id": self.donor_id,
            "match_id": self.match_id,
            "donor_name": self.donor.full_name if self.donor else None,
            "hospital_name": self.hospital_name,
            "donation_date": self.donation_date.isoformat(),
            "units_donated": self.units_donated,
        }


class AuditLog(db.Model):
    __tablename__ = "audit_logs"

    id = db.Column(db.Integer, primary_key=True)
    actor_type = db.Column(db.String(20), nullable=False)  # admin, hospital, donor, system
    actor_id = db.Column(db.Integer, nullable=True)
    action = db.Column(db.String(255), nullable=False)
    details = db.Column(db.String(500), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            "id": self.id,
            "actor_type": self.actor_type,
            "actor_id": self.actor_id,
            "action": self.action,
            "details": self.details,
            "created_at": self.created_at.isoformat(),
        }


def log_action(actor_type, actor_id, action, details=None):
    entry = AuditLog(actor_type=actor_type, actor_id=actor_id, action=action, details=details)
    db.session.add(entry)
    db.session.commit()
