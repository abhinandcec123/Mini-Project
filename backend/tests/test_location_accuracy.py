import unittest

from app import create_app
from extensions import bcrypt, db
from models import Donor


class DonorLocationAccuracyTests(unittest.TestCase):
    def setUp(self):
        self.app = create_app({
            "TESTING": True,
            "SQLALCHEMY_DATABASE_URI": "sqlite:///:memory:",
            "JWT_SECRET_KEY": "test-secret-key-with-at-least-32-bytes",
        })
        self.client = self.app.test_client()
        with self.app.app_context():
            db.create_all()
            donor = Donor(
                full_name="Test Donor",
                phone="1234567890",
                password_hash=bcrypt.generate_password_hash("donor-password").decode(),
                blood_group="O+",
                age=30,
            )
            db.session.add(donor)
            db.session.commit()
        login = self.client.post("/api/auth/donor/login", json={
            "phone": "1234567890",
            "password": "donor-password",
        })
        self.headers = {
            "Authorization": f"Bearer {login.get_json()['token']}",
        }

    def tearDown(self):
        with self.app.app_context():
            db.session.remove()
            db.drop_all()

    def test_browser_accuracy_within_500_meters_allows_availability(self):
        location = self.client.put(
            "/api/donor/location",
            headers=self.headers,
            json={
                "latitude": 9.247579,
                "longitude": 76.650979,
                "accuracy_m": 209,
            },
        )
        self.assertEqual(location.status_code, 200)

        available = self.client.post(
            "/api/donor/availability",
            headers=self.headers,
            json={"is_available": True},
        )
        self.assertEqual(available.status_code, 200)
        self.assertTrue(available.get_json()["is_available"])

    def test_location_accuracy_over_500_meters_is_rejected(self):
        response = self.client.put(
            "/api/donor/location",
            headers=self.headers,
            json={
                "latitude": 9.247579,
                "longitude": 76.650979,
                "accuracy_m": 501,
            },
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("500 meters", response.get_json()["error"])


if __name__ == "__main__":
    unittest.main()
