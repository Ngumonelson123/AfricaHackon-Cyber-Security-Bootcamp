<?php
// Data Update: update a student's email based on their id.
// Usage: php update.php <id> <new_email>
require 'db_config.php';

if ($argc !== 3) {
    die("Usage: php update.php <id> <new_email>\n");
}

[$script, $id, $newEmail] = $argv;

$stmt = $conn->prepare("UPDATE students SET email = ? WHERE id = ?");
$stmt->bind_param("si", $newEmail, $id);

if ($stmt->execute()) {
    if ($stmt->affected_rows > 0) {
        echo "Updated student id $id -> email: $newEmail\n";
    } else {
        echo "No student found with id $id\n";
    }
} else {
    echo "Update failed: " . $stmt->error . "\n";
}

$stmt->close();
$conn->close();
