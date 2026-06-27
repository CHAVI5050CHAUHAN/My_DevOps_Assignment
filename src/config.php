<?php
define("DB_SERVER", "mysql");
define("DB_USERNAME", "root");
define("DB_PASSWORD", "root123");
define("DB_NAME", "assignmentdb");

$link = mysqli_connect(DB_SERVER, DB_USERNAME, DB_PASSWORD, DB_NAME);

if (!$link) {
    die("Connection failed: " . mysqli_connect_error());
}
?>
