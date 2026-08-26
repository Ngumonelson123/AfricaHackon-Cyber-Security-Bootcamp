<?php
// Data Deletion: delete a student record based on their id.
// Usage: php delete.php <id>
require 'db_config.php';

if ($argc !== 2) {
    die("Usage: php delete.php <id>\n");
}

[$script, $id] = $argv;

$stmt = $conn->prepare("DELETE FROM students WHERE id = ?");
$stmt->bind_param("i", $id);

if ($stmt->execute()) {
    if ($stmt->affected_rows > 0) {
        echo "Deleted student id $id\n";
    } else {
        echo "No student found with id $id\n";
    }
} else {
    echo "Delete failed: " . $stmt->error . "\n";
}

$stmt->close();
$conn->close();
