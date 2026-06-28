<?php

define("DB_SERVER", "mysql");
define("DB_USERNAME", "app_user");
define("DB_PASSWORD", "app_pass");
define("DB_NAME", "app_db");

/* Connect to MySQL database */
$link = mysqli_connect(
    DB_SERVER,
    DB_USERNAME,
    DB_PASSWORD,
    DB_NAME
);

/* Check connection */
if ($link === false) {
    die("ERROR: Could not connect. " . mysqli_connect_error());
}

?>
