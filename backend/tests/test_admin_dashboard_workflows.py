import unittest

from app import create_app
from extensions import bcrypt, db
from models import (
    Admin,
    BloodRequest,
    DonationCertificate,
    Donor,
    Hospital,
    RequestMatch,
)
from db_config import TEST_DATABASE_URI


class AdminDashboardWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.app = create_app({
            "TESTING": True,
            "SQLALCHEMY_DATABASE_URI": TEST_DATABASE_URI,
            "JWT_SECRET_KEY": "test-secret-key-with-at-least-32-bytes",
            "GOOGLE_MAPS_API_KEY": None,
        })
        self.client = self.app.test_client()
        with self.app.app_context():
            db.create_all()
            db.session.add_all([
                Admin(
                    full_name="Admin",
                    email="admin@example.test",
                    password_hash=bcrypt.generate_password_hash("admin-password").decode(),
                ),
                Donor(
                    full_name="Donor One",
                    phone="1111111111",
                    password_hash=bcrypt.generate_password_hash("donor-password").decode(),
                    blood_group="O+",
                    age=30,
                    city="Harbor City",
                ),
                Hospital(
                    name="Harbor Hospital",
                    registration_number="HARBOR-1",
                    phone="2222222222",
                    password_hash=bcrypt.generate_password_hash("hospital-password").decode(),
                    city="Harbor City",
                ),
            ])
            db.session.commit()

        admin_login = self.client.post("/api/auth/admin/login", json={
            "email": "admin@example.test",
            "password": "admin-password",
        })
        self.assertEqual(admin_login.status_code, 200, admin_login.get_json())
        self.admin_headers = {
            "Authorization": f"Bearer {admin_login.get_json()['token']}",
        }

    def tearDown(self):
        with self.app.app_context():
            db.session.remove()
            db.drop_all()

    def test_removed_donor_disappears_and_loses_network_access(self):
        donor_login = self.client.post("/api/auth/donor/login", json={
            "phone": "1111111111",
            "password": "donor-password",
        })
        donor_headers = {
            "Authorization": f"Bearer {donor_login.get_json()['token']}",
        }

        removed = self.client.delete(
            "/api/admin/donors/1", headers=self.admin_headers
        )
        self.assertEqual(removed.status_code, 200, removed.get_json())
        self.assertEqual(
            self.client.get("/api/admin/donors", headers=self.admin_headers).get_json(),
            [],
        )
        self.assertEqual(self.client.get("/api/donor/me", headers=donor_headers).status_code, 403)
        self.assertEqual(
            self.client.get("/api/admin/donor-locations", headers=self.admin_headers).get_json(),
            [],
        )

    def test_removed_hospital_disappears_and_cancels_open_requests(self):
        hospital_login = self.client.post("/api/auth/hospital/login", json={
            "phone": "2222222222",
            "password": "hospital-password",
        })
        hospital_headers = {
            "Authorization": f"Bearer {hospital_login.get_json()['token']}",
        }
        with self.app.app_context():
            hospital = Hospital.query.filter_by(phone="2222222222").one()
            db.session.add(BloodRequest(
                hospital_id=hospital.id,
                patient_name="Test Patient",
                blood_group="O+",
                units_needed=1,
                status="open",
            ))
            db.session.commit()

        removed = self.client.delete(
            "/api/admin/hospitals/1", headers=self.admin_headers
        )
        self.assertEqual(removed.status_code, 200, removed.get_json())
        self.assertEqual(
            self.client.get("/api/admin/hospitals", headers=self.admin_headers).get_json(),
            [],
        )
        self.assertEqual(
            self.client.get("/api/hospital/me", headers=hospital_headers).status_code,
            403,
        )
        with self.app.app_context():
            self.assertEqual(BloodRequest.query.one().status, "cancelled")

    def test_inventory_is_grouped_by_city_and_blood_group(self):
        with self.app.app_context():
            donor = Donor.query.filter_by(phone="1111111111").one()
            donor.is_available = True
            donor.location_sharing_enabled = True
            donor.gps_latitude = 12.5
            donor.gps_longitude = 77.5
            donor.gps_location_source = "gps"
            db.session.commit()

        inventory = self.client.get(
            "/api/admin/inventory", headers=self.admin_headers
        )
        self.assertEqual(inventory.status_code, 200, inventory.get_json())
        self.assertEqual(
            inventory.get_json(),
            {"Harbor City": {"total": 1, "O+": 1}},
        )

    def test_fulfilled_requests_report_completed_units_without_location_map(self):
        with self.app.app_context():
            hospital = Hospital.query.filter_by(phone="2222222222").one()
            donor = Donor.query.filter_by(phone="1111111111").one()
            request = BloodRequest(
                hospital_id=hospital.id,
                patient_name="Two Unit Patient",
                blood_group="O+",
                units_needed=2,
                status="fulfilled",
            )
            db.session.add(request)
            db.session.flush()
            second_donor = Donor(
                full_name="Donor Two",
                phone="3333333333",
                password_hash=bcrypt.generate_password_hash("donor-password").decode(),
                blood_group="O+",
                age=32,
            )
            db.session.add(second_donor)
            db.session.flush()
            match = RequestMatch(
                request_id=request.id,
                donor_id=donor.id,
                status="completed",
            )
            db.session.add(match)
            db.session.flush()
            second_match = RequestMatch(
                request_id=request.id,
                donor_id=second_donor.id,
                status="completed",
            )
            db.session.add(second_match)
            db.session.flush()
            db.session.add(DonationCertificate(
                donor_id=donor.id,
                match_id=match.id,
                hospital_name=hospital.name,
                units_donated=1,
            ))
            db.session.add(DonationCertificate(
                donor_id=second_donor.id,
                match_id=second_match.id,
                hospital_name=hospital.name,
                units_donated=1,
            ))
            db.session.commit()

        report = self.client.get(
            "/api/admin/fulfilled-donations", headers=self.admin_headers
        )
        self.assertEqual(report.status_code, 200, report.get_json())
        data = report.get_json()
        self.assertEqual(data["total_fulfilled_requests"], 1)
        self.assertEqual(data["total_completed_donations"], 2)
        self.assertEqual(data["fulfilled_requests"][0]["approved_units"], 2)
        self.assertNotIn("completed_donor_locations", data)

    def test_bulk_import_creates_accounts_and_reports_skipped_rows(self):
        response = self.client.post(
            "/api/admin/bulk-users",
            headers=self.admin_headers,
            json={
                "donors": [{
                    "full_name": "Imported Donor",
                    "phone": "3333333333",
                    "blood_group": "A+",
                    "city": "Harbor City",
                    "age": 26,
                }],
                "hospitals": [{
                    "name": "Imported Hospital",
                    "phone": "4444444444",
                    "city": "Harbor City",
                }],
            },
        )
        self.assertEqual(response.status_code, 201, response.get_json())
        data = response.get_json()
        self.assertEqual(data["created_donors_count"], 1)
        self.assertEqual(data["created_hospitals_count"], 1)
        self.assertEqual(data["errors"], [])
        self.assertEqual(len(self.client.get(
            "/api/admin/donors", headers=self.admin_headers
        ).get_json()), 2)
        self.assertEqual(len(self.client.get(
            "/api/admin/hospitals", headers=self.admin_headers
        ).get_json()), 2)


if __name__ == "__main__":
    unittest.main()
