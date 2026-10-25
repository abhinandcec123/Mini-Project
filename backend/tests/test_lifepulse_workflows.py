import unittest

from app import create_app
from extensions import bcrypt, db
from models import Admin, Donor, Hospital
from db_config import TEST_DATABASE_URI


class LifePulseWorkflowTests(unittest.TestCase):
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
                name="Workflow Hospital",
                registration_number="WORKFLOW-001",
                phone="1234567890",
                password_hash=bcrypt.generate_password_hash("hospital-password").decode(),
                is_verified=False,
            )
            self.donor = Donor(
                full_name="Workflow Donor",
                phone="0987654321",
                password_hash=bcrypt.generate_password_hash("donor-password").decode(),
                blood_group="O+",
                age=30,
                total_donations=1,
                reliability_score=80,
            )
            self.compatible_donor = Donor(
                full_name="Compatible Donor",
                phone="0987654322",
                password_hash=bcrypt.generate_password_hash("donor-password").decode(),
                blood_group="O-",
                age=32,
                total_donations=1,
                reliability_score=80,
            )
            self.incompatible_donor = Donor(
                full_name="Incompatible Donor",
                phone="0987654323",
                password_hash=bcrypt.generate_password_hash("donor-password").decode(),
                blood_group="A+",
                age=28,
            )
            self.admin = Admin(
                full_name="Workflow Admin",
                email="admin@example.test",
                password_hash=bcrypt.generate_password_hash("admin-password").decode(),
            )
            db.session.add_all([
                self.hospital,
                self.donor,
                self.compatible_donor,
                self.incompatible_donor,
                self.admin,
            ])
            db.session.commit()
            self.hospital_id = self.hospital.id
            self.donor_id = self.donor.id
            self.compatible_donor_id = self.compatible_donor.id
            self.incompatible_donor_id = self.incompatible_donor.id

        self.hospital_headers = self._login(
            "/api/auth/hospital/login",
            {"phone": "1234567890", "password": "hospital-password"},
        )
        self.donor_headers = self._login(
            "/api/auth/donor/login",
            {"phone": "0987654321", "password": "donor-password"},
        )
        self.compatible_donor_headers = self._login(
            "/api/auth/donor/login",
            {"phone": "0987654322", "password": "donor-password"},
        )
        self.admin_headers = self._login(
            "/api/auth/admin/login",
            {"email": "admin@example.test", "password": "admin-password"},
        )

    def _login(self, path, payload):
        response = self.client.post(path, json=payload)
        self.assertEqual(response.status_code, 200, response.get_json())
        return {"Authorization": f"Bearer {response.get_json()['token']}"}

    def tearDown(self):
        with self.app.app_context():
            db.session.remove()
            db.drop_all()

    def test_hospital_donor_and_certificate_workflow(self):
        location = self.client.put(
            "/api/hospital/location",
            headers=self.hospital_headers,
            json={"latitude": 12.9716, "longitude": 77.5946, "accuracy_m": 10},
        )
        self.assertEqual(location.status_code, 200)

        for headers, latitude in (
            (self.donor_headers, 12.9717),
            (self.compatible_donor_headers, 12.9800),
        ):
            pin = self.client.put(
                "/api/donor/location/pin",
                headers=headers,
                json={"latitude": latitude, "longitude": 77.5946},
            )
            self.assertEqual(pin.status_code, 200)
            availability = self.client.post(
                "/api/donor/availability",
                headers=headers,
                json={"is_available": True},
            )
            self.assertEqual(availability.status_code, 200)

        created = self.client.post(
            "/api/hospital/requests",
            headers=self.hospital_headers,
            json={
                "patient_name": "Workflow Patient",
                "blood_group": "O+",
                "units_needed": 1,
                "priority": "urgent",
            },
        )
        self.assertEqual(created.status_code, 201, created.get_json())
        request_id = created.get_json()["id"]

        requests = self.client.get(
            "/api/hospital/requests",
            headers=self.hospital_headers,
        )
        self.assertEqual(requests.status_code, 200)
        self.assertEqual(requests.get_json()[0]["id"], request_id)

        candidates = self.client.get(
            f"/api/hospital/requests/{request_id}/candidates",
            headers=self.hospital_headers,
        )
        self.assertEqual(candidates.status_code, 200)
        candidate_ids = [candidate["donor"]["id"] for candidate in candidates.get_json()]
        self.assertEqual(candidate_ids[:2], [self.donor_id, self.compatible_donor_id])
        self.assertNotIn(self.incompatible_donor_id, candidate_ids)

        dispatched = self.client.post(
            f"/api/hospital/requests/{request_id}/dispatch/{self.donor_id}",
            headers=self.hospital_headers,
        )
        self.assertEqual(dispatched.status_code, 201, dispatched.get_json())
        match_id = dispatched.get_json()["id"]

        incoming = self.client.get(
            "/api/donor/requests",
            headers=self.donor_headers,
        )
        self.assertEqual(incoming.status_code, 200)
        self.assertEqual(incoming.get_json()[0]["status"], "pending")

        accepted = self.client.post(
            f"/api/donor/requests/{match_id}/accept",
            headers=self.donor_headers,
        )
        self.assertEqual(accepted.status_code, 200)
        self.assertEqual(accepted.get_json()["status"], "accepted")

        matches = self.client.get(
            f"/api/hospital/requests/{request_id}/matches",
            headers=self.hospital_headers,
        )
        self.assertEqual(matches.status_code, 200)
        self.assertEqual(matches.get_json()[0]["status"], "accepted")

        confirmed = self.client.post(
            f"/api/hospital/requests/{request_id}/matches/{match_id}/confirm",
            headers=self.hospital_headers,
        )
        self.assertEqual(confirmed.status_code, 200, confirmed.get_json())
        self.assertEqual(confirmed.get_json()["request"]["status"], "fulfilled")

        certificates = self.client.get(
            "/api/donor/certificates",
            headers=self.donor_headers,
        )
        self.assertEqual(certificates.status_code, 200)
        self.assertEqual(len(certificates.get_json()), 1)
        self.assertEqual(certificates.get_json()[0]["match_id"], match_id)

    def test_administrator_management_and_reporting_workflow(self):
        verify = self.client.post(
            f"/api/admin/hospitals/{self.hospital_id}/verify",
            headers=self.admin_headers,
        )
        self.assertEqual(verify.status_code, 200)
        self.assertTrue(verify.get_json()["is_verified"])

        donor_list = self.client.get(
            "/api/admin/donors",
            headers=self.admin_headers,
        )
        self.assertEqual(donor_list.status_code, 200)
        self.assertEqual(len(donor_list.get_json()), 3)

        hospital_list = self.client.get(
            "/api/admin/hospitals",
            headers=self.admin_headers,
        )
        self.assertEqual(hospital_list.status_code, 200)
        self.assertTrue(hospital_list.get_json()[0]["is_verified"])

        stats = self.client.get("/api/admin/stats", headers=self.admin_headers)
        self.assertEqual(stats.status_code, 200)
        self.assertEqual(stats.get_json()["total_donors"], 3)
        self.assertEqual(stats.get_json()["total_hospitals"], 1)

        inventory = self.client.get(
            "/api/admin/inventory",
            headers=self.admin_headers,
        )
        self.assertEqual(inventory.status_code, 200)
        self.assertEqual(inventory.get_json(), {})

        audit_logs = self.client.get(
            "/api/admin/audit-logs",
            headers=self.admin_headers,
        )
        self.assertEqual(audit_logs.status_code, 200)
        self.assertTrue(
            any(entry["action"] == "verified_hospital" for entry in audit_logs.get_json())
        )


if __name__ == "__main__":
    unittest.main()
