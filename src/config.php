<?php
define("DB_SERVER", "mysql");
define("DB_USERNAME", "app_user");
define("DB_PASSWORD", "app_pass");
define("DB_NAME", "app_db");

$link = mysqli_connect(DB_SERVER, DB_USERNAME, DB_PASSWORD, DB_NAME);

if (!$link) {
    die("Connection failed: " . mysqli_connect_error());
}
?>
