import os
from urllib.parse import urlparse


TEST_DATABASE_URI = os.environ.get(
    "LIFEPULSE_TEST_DATABASE_URI",
    "sqlite:///:memory:",
)

if TEST_DATABASE_URI.startswith(("mysql://", "mysql+", "mariadb://", "mariadb+")):
    database_name = urlparse(TEST_DATABASE_URI).path.lstrip("/").split("?")[0]
    if database_name != "lifepulse_test":
        raise RuntimeError(
            "Backend tests may use MySQL only with the dedicated lifepulse_test database."
        )
