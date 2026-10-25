import unittest

from app import create_app
from extensions import bcrypt, db
from models import Admin, Donor
from db_config import TEST_DATABASE_URI


class DonorLocationMapTests(unittest.TestCase):
    def setUp(self):
        self.app = create_app({
            "TESTING": True,
            "SQLALCHEMY_DATABASE_URI": TEST_DATABASE_URI,
            "JWT_SECRET_KEY": "test-secret-key-with-at-least-32-bytes",
        })
        self.client = self.app.test_client()
        with self.app.app_context():
            db.create_all()
            db.session.add_all([
                Donor(
                    full_name="Test Donor",
                    phone="1234567890",
                    password_hash=bcrypt.generate_password_hash("donor-password").decode(),
                    blood_group="O+",
                    age=30,
                ),
                Admin(
                    full_name="Test Admin",
                    email="admin@example.com",
                    password_hash=bcrypt.generate_password_hash("admin-password").decode(),
                ),
            ])
            db.session.commit()

        donor_login = self.client.post("/api/auth/donor/login", json={
            "phone": "1234567890",
            "password": "donor-password",
        })
        admin_login = self.client.post("/api/auth/admin/login", json={
            "email": "admin@example.com",
            "password": "admin-password",
        })
        self.donor_headers = {
            "Authorization": f"Bearer {donor_login.get_json()['token']}",
        }
        self.admin_headers = {
            "Authorization": f"Bearer {admin_login.get_json()['token']}",
        }

    def tearDown(self):
        with self.app.app_context():
            db.session.remove()
            db.drop_all()

    def test_manual_pin_is_private_until_donor_is_available(self):
        response = self.client.put(
            "/api/donor/location/pin",
            headers=self.donor_headers,
            json={"latitude": 12.9716, "longitude": 77.5946},
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.get_json()["gps_location_source"], "test_pin")

        locations = self.client.get(
            "/api/admin/donor-locations",
            headers=self.admin_headers,
        )
        self.assertEqual(locations.status_code, 200)
        self.assertEqual(locations.get_json(), [])

        availability = self.client.post(
            "/api/donor/availability",
            headers=self.donor_headers,
            json={"is_available": True},
        )
        self.assertEqual(availability.status_code, 200)

        locations = self.client.get(
            "/api/admin/donor-locations",
            headers=self.admin_headers,
        )
        self.assertEqual(locations.status_code, 200)
        shared = locations.get_json()
        self.assertEqual(len(shared), 1)
        self.assertEqual(shared[0]["location_source"], "test_pin")
        self.assertEqual(shared[0]["latitude"], 12.9716)
        self.assertNotIn("phone", shared[0])
        self.assertNotIn("email", shared[0])

        self.client.post(
            "/api/donor/availability",
            headers=self.donor_headers,
            json={"is_available": False},
        )
        locations = self.client.get(
            "/api/admin/donor-locations",
            headers=self.admin_headers,
        )
        self.assertEqual(locations.get_json(), [])

    def test_manual_pin_rejects_invalid_coordinates(self):
        response = self.client.put(
            "/api/donor/location/pin",
            headers=self.donor_headers,
            json={"latitude": 91, "longitude": 76},
        )
        self.assertEqual(response.status_code, 400)


if __name__ == "__main__":
    unittest.main()
