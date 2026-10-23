import os
from datetime import timedelta
from dotenv import load_dotenv

load_dotenv()

BASE_DIR = os.path.abspath(os.path.dirname(__file__))


class Config:
    APP_ENV = os.getenv("APP_ENV", "development").strip().lower()
    if APP_ENV not in {"development", "production"}:
        raise RuntimeError("APP_ENV must be either 'development' or 'production'.")

    MYSQL_HOST = os.getenv("MYSQL_HOST", "localhost")
    MYSQL_PORT = os.getenv("MYSQL_PORT", "3306")
    MYSQL_USER = os.getenv("MYSQL_USER", "root")
    MYSQL_PASSWORD = os.getenv("MYSQL_PASSWORD", "")
    MYSQL_DB = os.getenv("MYSQL_DB", "lifepulse_db")

    USE_SQLITE = os.getenv("USE_SQLITE", "false").lower() in {"1", "true", "yes", "on"}
    if USE_SQLITE:
        SQLALCHEMY_DATABASE_URI = f"sqlite:///{os.path.join(BASE_DIR, 'lifepulse.db')}"
    else:
        SQLALCHEMY_DATABASE_URI = (
            f"mysql+pymysql://{MYSQL_USER}:{MYSQL_PASSWORD}"
            f"@{MYSQL_HOST}:{MYSQL_PORT}/{MYSQL_DB}"
        )
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY") or "dev-secret-change-me"
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(days=7)
    GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY")
    FLASK_DEBUG = APP_ENV == "development" and os.getenv("FLASK_DEBUG", "false").lower() in {"1", "true", "yes", "on"}
    CORS_ORIGINS = [
        origin.strip()
        for origin in os.getenv("CORS_ORIGINS", "*").split(",")
        if origin.strip()
    ]

    if APP_ENV == "production":
        required = {
            "JWT_SECRET_KEY": os.getenv("JWT_SECRET_KEY"),
            "MYSQL_HOST": os.getenv("MYSQL_HOST"),
            "MYSQL_PORT": os.getenv("MYSQL_PORT"),
            "MYSQL_USER": os.getenv("MYSQL_USER"),
            "MYSQL_PASSWORD": os.getenv("MYSQL_PASSWORD"),
            "MYSQL_DB": os.getenv("MYSQL_DB"),
            "CORS_ORIGINS": os.getenv("CORS_ORIGINS"),
        }
        missing = [name for name, value in required.items() if not value]
        if missing:
            raise RuntimeError(
                "Production configuration is missing required environment variables: "
                + ", ".join(missing)
            )
        if USE_SQLITE:
            raise RuntimeError("SQLite is not supported by this production configuration; configure MySQL.")
        if "*" in CORS_ORIGINS:
            raise RuntimeError("CORS_ORIGINS must list approved website origins in production.")
        if any(not origin.lower().startswith("https://") for origin in CORS_ORIGINS):
            raise RuntimeError("Production CORS_ORIGINS must use HTTPS website origins.")
        if len(JWT_SECRET_KEY) < 32 or JWT_SECRET_KEY in {
            "dev-secret-change-me",
            "change-this-to-a-long-random-secret",
        }:
            raise RuntimeError("JWT_SECRET_KEY must be a unique random value of at least 32 characters in production.")
        if MYSQL_PASSWORD == "your_mysql_password":
            raise RuntimeError("MYSQL_PASSWORD must be explicitly configured in production.")

    JSON_SORT_KEYS = False
