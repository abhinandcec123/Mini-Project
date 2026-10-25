import unittest

from app import create_app
from extensions import bcrypt, db
from models import (
    BloodRequest,
    DonationCertificate,
    Donor,
    Hospital,
    RequestMatch,
)
from db_config import TEST_DATABASE_URI


class HospitalDonationApprovalTests(unittest.TestCase):
    def setUp(self):
        self.app = create_app({
            "TESTING": True,
            "SQLALCHEMY_DATABASE_URI": TEST_DATABASE_URI,
            "JWT_SECRET_KEY": "test-secret-key-with-at-least-32-bytes",
        })
        self.client = self.app.test_client()
        with self.app.app_context():
            db.create_all()
            self.hospital = Hospital(
                name="Test Hospital",
                registration_number="TEST-001",
                phone="1234567890",
                password_hash=bcrypt.generate_password_hash("hospital-password").decode(),
            )
            self.donor = Donor(
                full_name="Test Donor",
                phone="0987654321",
                password_hash=bcrypt.generate_password_hash("donor-password").decode(),
                blood_group="O+",
                age=30,
                total_donations=1,
                reliability_score=80,
            )
            db.session.add_all([self.hospital, self.donor])
            db.session.flush()
            self.request = BloodRequest(
                hospital_id=self.hospital.id,
                patient_name="Test Patient",
                blood_group="O+",
                units_needed=1,
                status="open",
            )
            db.session.add(self.request)
            db.session.flush()
            self.match = RequestMatch(
                request_id=self.request.id,
                donor_id=self.donor.id,
                status="accepted",
            )
            db.session.add(self.match)
            db.session.commit()
            self.request_id = self.request.id
            self.match_id = self.match.id
            self.donor_id = self.donor.id

        login = self.client.post("/api/auth/hospital/login", json={
            "phone": "1234567890",
            "password": "hospital-password",
        })
        self.headers = {
            "Authorization": f"Bearer {login.get_json()['token']}",
        }

    def tearDown(self):
        with self.app.app_context():
            db.session.remove()
            db.drop_all()

    def test_hospital_approval_completes_match_and_issues_certificate(self):
        response = self.client.post(
            f"/api/hospital/requests/{self.request_id}/matches/{self.match_id}/confirm",
            headers=self.headers,
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()["match"]["status"], "completed")
        self.assertEqual(response.get_json()["certificate"]["donor_id"], self.donor_id)

        with self.app.app_context():
            donor = db.session.get(Donor, self.donor_id)
            request = db.session.get(BloodRequest, self.request_id)
            self.assertEqual(request.status, "fulfilled")
            self.assertEqual(donor.total_donations, 2)
            self.assertEqual(donor.reliability_score, 82)
            self.assertEqual(
                DonationCertificate.query.filter_by(match_id=self.match_id).count(),
                1,
            )

    def test_non_accepted_match_cannot_be_approved(self):
        with self.app.app_context():
            match = db.session.get(RequestMatch, self.match_id)
            match.status = "pending"
            db.session.commit()

        response = self.client.post(
            f"/api/hospital/requests/{self.request_id}/matches/{self.match_id}/confirm",
            headers=self.headers,
        )
        self.assertEqual(response.status_code, 400)

    def test_multi_unit_request_stays_open_until_enough_donors_approved(self):
        with self.app.app_context():
            request = db.session.get(BloodRequest, self.request_id)
            request.units_needed = 2
            second_donor = Donor(
                full_name="Second Donor",
                phone="1112223333",
                password_hash=bcrypt.generate_password_hash("donor-password").decode(),
                blood_group="O+",
                age=32,
            )
            db.session.add(second_donor)
            db.session.flush()
            second_match = RequestMatch(
                request_id=self.request_id,
                donor_id=second_donor.id,
                status="accepted",
            )
            db.session.add(second_match)
            db.session.commit()
            second_match_id = second_match.id

        first_approval = self.client.post(
            f"/api/hospital/requests/{self.request_id}/matches/{self.match_id}/confirm",
            headers=self.headers,
        )
        self.assertEqual(first_approval.status_code, 200)
        self.assertEqual(first_approval.get_json()["certificate"]["units_donated"], 1)
        self.assertEqual(first_approval.get_json()["request"]["status"], "open")
        self.assertEqual(first_approval.get_json()["approved_units"], 1)

        second_approval = self.client.post(
            f"/api/hospital/requests/{self.request_id}/matches/{second_match_id}/confirm",
            headers=self.headers,
        )
        self.assertEqual(second_approval.status_code, 200)
        self.assertEqual(second_approval.get_json()["certificate"]["units_donated"], 1)
        self.assertEqual(second_approval.get_json()["request"]["status"], "fulfilled")
        self.assertEqual(second_approval.get_json()["approved_units"], 2)

    def test_same_donor_cannot_be_approved_twice_within_eligibility_interval(self):
        first = self.client.post(
            f"/api/hospital/requests/{self.request_id}/matches/{self.match_id}/confirm",
            headers=self.headers,
        )
        self.assertEqual(first.status_code, 200)

        with self.app.app_context():
            second_request = BloodRequest(
                hospital_id=1,
                patient_name="Second Patient",
                blood_group="O+",
                units_needed=1,
            )
            db.session.add(second_request)
            db.session.flush()
            second_match = RequestMatch(
                request_id=second_request.id,
                donor_id=self.donor_id,
                status="accepted",
            )
            db.session.add(second_match)
            db.session.commit()
            second_request_id = second_request.id
            second_match_id = second_match.id

        second = self.client.post(
            f"/api/hospital/requests/{second_request_id}/matches/{second_match_id}/confirm",
            headers=self.headers,
        )
        self.assertEqual(second.status_code, 409)
        self.assertIn("90-day interval", second.get_json()["error"])

    def test_request_cannot_be_manually_fulfilled_before_all_units_are_approved(self):
        with self.app.app_context():
            request = db.session.get(BloodRequest, self.request_id)
            request.units_needed = 2
            db.session.commit()

        response = self.client.post(
            f"/api/hospital/requests/{self.request_id}/fulfill",
            headers=self.headers,
        )
        self.assertEqual(response.status_code, 409)
        self.assertIn("distinct donor", response.get_json()["error"])


if __name__ == "__main__":
    unittest.main()
