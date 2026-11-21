<?php
// Railway health check (/healthz): 200 when Ampache is configured and its database answers.
header('Content-Type: text/plain');
header('Cache-Control: no-store');
$cfg = @parse_ini_file('/var/www/config/ampache.cfg.php');
if (!$cfg || empty($cfg['database_hostname'])) {
    http_response_code(503);
    exit("not configured\n");
}
try {
    $dsn = 'mysql:host=' . $cfg['database_hostname'] . ';port=' . (int) ($cfg['database_port'] ?? 3306) . ';dbname=' . $cfg['database_name'];
    $pdo = new PDO($dsn, $cfg['database_username'], $cfg['database_password'], [PDO::ATTR_TIMEOUT => 3, PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    $pdo->query('SELECT 1 FROM `update_info` LIMIT 1');
} catch (Throwable $e) {
    http_response_code(503);
    exit("database unavailable\n");
}
echo "ok\n";
