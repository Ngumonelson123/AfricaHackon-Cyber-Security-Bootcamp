-- student_records database schema
-- Run with: mysql -u root -p < schema.sql

CREATE DATABASE IF NOT EXISTS student_records;
USE student_records;

CREATE TABLE IF NOT EXISTS students (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    age INT NOT NULL,
    email VARCHAR(100) NOT NULL
);

INSERT INTO students (name, age, email) VALUES
    ('Alice Wanjiru', 21, 'alice.wanjiru@example.com'),
    ('Brian Otieno', 23, 'brian.otieno@example.com'),
    ('Cynthia Mumbi', 22, 'cynthia.mumbi@example.com');
