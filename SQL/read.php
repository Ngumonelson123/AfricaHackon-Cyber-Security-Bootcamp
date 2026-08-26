<?php
// Data Retrieval: connect to MySQL and display all student records in an HTML table.
require 'db_config.php';

$result = $conn->query("SELECT id, name, age, email FROM students ORDER BY id");
?>
<!DOCTYPE html>
<html>
<head>
    <title>Student Records</title>
    <style>
        table { border-collapse: collapse; width: 60%; font-family: sans-serif; }
        th, td { border: 1px solid #444; padding: 8px 12px; text-align: left; }
        th { background: #222; color: #fff; }
        tr:nth-child(even) { background: #f2f2f2; }
    </style>
</head>
<body>
    <h2>Student Records</h2>
    <table>
        <tr><th>ID</th><th>Name</th><th>Age</th><th>Email</th></tr>
        <?php while ($row = $result->fetch_assoc()): ?>
        <tr>
            <td><?= htmlspecialchars($row['id']) ?></td>
            <td><?= htmlspecialchars($row['name']) ?></td>
            <td><?= htmlspecialchars($row['age']) ?></td>
            <td><?= htmlspecialchars($row['email']) ?></td>
        </tr>
        <?php endwhile; ?>
    </table>
</body>
</html>
<?php
$conn->close();
