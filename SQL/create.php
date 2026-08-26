<?php
// Data Insertion: add a new student record via a prepared statement.
// Usage: php create.php "Full Name" age email@example.com
require 'db_config.php';

if ($argc !== 4) {
    die("Usage: php create.php \"Full Name\" age email@example.com\n");
}

[$script, $name, $age, $email] = $argv;

$stmt = $conn->prepare("INSERT INTO students (name, age, email) VALUES (?, ?, ?)");
$stmt->bind_param("sis", $name, $age, $email);

if ($stmt->execute()) {
    echo "Inserted student id " . $conn->insert_id . ": $name, $age, $email\n";
} else {
    echo "Insert failed: " . $stmt->error . "\n";
}

$stmt->close();
$conn->close();
