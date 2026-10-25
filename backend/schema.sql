-- Reference schema. You do NOT need to run this by hand:
-- app.py calls db.create_all() automatically on first run, which builds
-- these same tables from models.py. This file is here for documentation
-- and for anyone who wants to provision the schema manually.

CREATE DATABASE IF NOT EXISTS lifepulse_db CHARACTER SET utf8mb4;
USE lifepulse_db;

CREATE TABLE IF NOT EXISTS donors (
    id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL,
    phone VARCHAR(15) NOT NULL UNIQUE,
    email VARCHAR(120) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    must_change_password BOOLEAN NOT NULL DEFAULT FALSE,
    password_version INT NOT NULL DEFAULT 0,
    blood_group VARCHAR(3) NOT NULL,
    age INT NOT NULL,
    gender VARCHAR(20),
    address VARCHAR(255),
    latitude FLOAT,
    longitude FLOAT,
    fallback_latitude FLOAT,
    fallback_longitude FLOAT,
    location_source VARCHAR(30),
    location_accuracy_km FLOAT,
    gps_latitude FLOAT,
    gps_longitude FLOAT,
    gps_accuracy_m FLOAT,
    gps_location_source VARCHAR(20),
    location_sharing_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    city VARCHAR(100),
    is_available BOOLEAN DEFAULT FALSE,
    reliability_score FLOAT DEFAULT 80.0,
    total_donations INT DEFAULT 0,
    last_donation_date DATETIME,
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS hospitals (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    registration_number VARCHAR(80) NOT NULL UNIQUE,
    phone VARCHAR(15) NOT NULL UNIQUE,
    email VARCHAR(120) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    must_change_password BOOLEAN NOT NULL DEFAULT FALSE,
    password_version INT NOT NULL DEFAULT 0,
    address VARCHAR(255),
    city VARCHAR(100),
    latitude FLOAT,
    longitude FLOAT,
    fallback_latitude FLOAT,
    fallback_longitude FLOAT,
    location_source VARCHAR(30),
    location_accuracy_km FLOAT,
    gps_accuracy_m FLOAT,
    is_verified BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS admins (
    id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(120) NOT NULL,
    email VARCHAR(120) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS blood_requests (
    id INT AUTO_INCREMENT PRIMARY KEY,
    hospital_id INT NOT NULL,
    patient_name VARCHAR(120) NOT NULL,
    blood_group VARCHAR(3) NOT NULL,
    units_needed INT DEFAULT 1,
    priority VARCHAR(20) DEFAULT 'normal',
    notes VARCHAR(500),
    status VARCHAR(20) DEFAULT 'open',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (hospital_id) REFERENCES hospitals(id)
);

CREATE TABLE IF NOT EXISTS request_matches (
    id INT AUTO_INCREMENT PRIMARY KEY,
    request_id INT NOT NULL,
    donor_id INT NOT NULL,
    match_score FLOAT,
    distance_km FLOAT,
    status VARCHAR(20) DEFAULT 'pending',
    dispatched_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    responded_at DATETIME,
    FOREIGN KEY (request_id) REFERENCES blood_requests(id),
    FOREIGN KEY (donor_id) REFERENCES donors(id)
);

CREATE TABLE IF NOT EXISTS donation_certificates (
    id INT AUTO_INCREMENT PRIMARY KEY,
    donor_id INT NOT NULL,
    match_id INT,
    hospital_name VARCHAR(150) NOT NULL,
    donation_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    units_donated INT DEFAULT 1,
    FOREIGN KEY (donor_id) REFERENCES donors(id),
    FOREIGN KEY (match_id) REFERENCES request_matches(id)
);

CREATE TABLE IF NOT EXISTS audit_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    actor_type VARCHAR(20) NOT NULL,
    actor_id INT,
    action VARCHAR(255) NOT NULL,
    details VARCHAR(500),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
