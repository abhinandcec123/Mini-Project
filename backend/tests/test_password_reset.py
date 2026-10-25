import unittest

from app import create_app
from extensions import bcrypt, db
from models import Admin, Donor
from db_config import TEST_DATABASE_URI


class TemporaryPasswordResetTests(unittest.TestCase):
    def setUp(self):
        self.app = create_app({
            "TESTING": True,
            "SQLALCHEMY_DATABASE_URI": TEST_DATABASE_URI,
            "JWT_SECRET_KEY": "test-secret-key-with-at-least-32-bytes",
        })
        self.client = self.app.test_client()
        with self.app.app_context():
            db.create_all()
            admin = Admin(
                full_name="Test Admin",
                email="admin@example.test",
                password_hash=bcrypt.generate_password_hash("admin-password").decode(),
            )
            donor = Donor(
                full_name="Test Donor",
                phone="1234567890",
                password_hash=bcrypt.generate_password_hash("donor-password").decode(),
                blood_group="O+",
                age=30,
            )
            db.session.add_all([admin, donor])
            db.session.commit()

    def tearDown(self):
        with self.app.app_context():
            db.session.remove()
            db.drop_all()

    def test_admin_reset_requires_change_and_invalidates_previous_sessions(self):
        admin_login = self.client.post("/api/auth/admin/login", json={
            "email": "admin@example.test",
            "password": "admin-password",
        })
        admin_token = admin_login.get_json()["token"]
        donor_login = self.client.post("/api/auth/donor/login", json={
            "phone": "1234567890",
            "password": "donor-password",
        })
        old_donor_token = donor_login.get_json()["token"]

        reset = self.client.post(
            "/api/admin/users/donor/1/temporary-password",
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        self.assertEqual(reset.status_code, 200)
        temporary_password = reset.get_json()["temporary_password"]

        self.assertEqual(
            self.client.get(
                "/api/donor/me",
                headers={"Authorization": f"Bearer {old_donor_token}"},
            ).status_code,
            401,
        )

        temporary_login = self.client.post("/api/auth/donor/login", json={
            "phone": "1234567890",
            "password": temporary_password,
        })
        self.assertTrue(temporary_login.get_json()["password_change_required"])
        temporary_token = temporary_login.get_json()["token"]
        self.assertEqual(
            self.client.get(
                "/api/donor/me",
                headers={"Authorization": f"Bearer {temporary_token}"},
            ).status_code,
            403,
        )

        changed = self.client.post(
            "/api/auth/change-password",
            headers={"Authorization": f"Bearer {temporary_token}"},
            json={
                "current_password": temporary_password,
                "new_password": "my-new-safe-password",
            },
        )
        self.assertEqual(changed.status_code, 200)
        self.assertFalse(changed.get_json()["password_change_required"])

        self.assertEqual(
            self.client.get(
                "/api/donor/me",
                headers={"Authorization": f"Bearer {temporary_token}"},
            ).status_code,
            401,
        )
        self.assertEqual(
            self.client.post("/api/auth/donor/login", json={
                "phone": "1234567890",
                "password": "my-new-safe-password",
            }).status_code,
            200,
        )

    def test_admin_cannot_reset_an_admin_password_through_user_endpoint(self):
        admin_login = self.client.post("/api/auth/admin/login", json={
            "email": "admin@example.test",
            "password": "admin-password",
        })
        response = self.client.post(
            "/api/admin/users/admin/1/temporary-password",
            headers={"Authorization": f"Bearer {admin_login.get_json()['token']}"},
        )
        self.assertEqual(response.status_code, 400)


if __name__ == "__main__":
    unittest.main()
