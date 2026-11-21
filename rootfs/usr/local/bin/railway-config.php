<?php
// Railway helper for Ampache's config file (/var/www/config/ampache.cfg.php -> /data/config).
//   (no args)         keep database_* in line with the DB_* variables and set Railway's HTTPS settings
//   --new             write a fresh config from ampache.cfg.php.dist (tables exist, config file was lost)
//   --enable-upload   allow uploads into the "music" catalog (first install only)
declare(strict_types=1);

const CFG  = '/var/www/config/ampache.cfg.php';
const DIST = '/var/www/config/ampache.cfg.php.dist';

$mode = $argv[1] ?? '';

function ini_quote(string $v): string
{
    return '"' . str_replace(['\\', '"'], ['\\\\', '\\"'], $v) . '"';
}

/** Set (or uncomment and set) `key = "value"` lines in an ampache.cfg.php text. */
function set_keys(string $text, array $values): string
{
    foreach ($values as $key => $value) {
        $line  = $key . ' = ' . ini_quote((string) $value);
        $count = 0;
        $text  = preg_replace('/^' . preg_quote($key, '/') . '\s*=.*$/m', addcslashes($line, '\\$'), $text, 1, $count);
        if ($count === 0) {
            $text = preg_replace('/^;' . preg_quote($key, '/') . '\s*=.*$/m', addcslashes($line, '\\$'), $text, 1, $count);
        }
        if ($count === 0) {
            $text .= "\n" . $line . "\n";
        }
    }

    return $text;
}

if ($mode === '--enable-upload') {
    define('NO_SESSION', '1');
    define('CLI', 1);
    define('OUTDATED_DATABASE_OK', 1);
    $dic = require '/var/www/src/Config/Init.php';
    $row = \Ampache\Module\System\Dba::fetch_assoc(
        \Ampache\Module\System\Dba::read("SELECT `id` FROM `catalog` WHERE `name` = 'music' LIMIT 1")
    );
    if (empty($row['id'])) {
        fwrite(STDERR, "no 'music' catalog\n");
        exit(1);
    }
    \Ampache\Module\System\Preference::update_all('upload_catalog', (int) $row['id']);
    \Ampache\Module\System\Preference::update_all('allow_upload', 1);
    exit(0);
}

$db = [
    'database_hostname' => getenv('DB_HOST') ?: '',
    'database_port'     => getenv('DB_PORT') ?: '3306',
    'database_name'     => getenv('DB_NAME') ?: '',
    'database_username' => getenv('DB_USER') ?: '',
    'database_password' => getenv('DB_PASSWORD') ?: '',
];
foreach ($db as $k => $v) {
    if ($v === '') {
        fwrite(STDERR, "missing value for $k\n");
        exit(1);
    }
}

if ($mode === '--new') {
    $text = file_get_contents(DIST);
    $text = set_keys($text, ['secret_key' => bin2hex(random_bytes(16))]);
} else {
    $text = file_get_contents(CFG);
}
if ($text === false) {
    fwrite(STDERR, "cannot read the config\n");
    exit(1);
}

$values = $db;
// On Railway the public domain (and any custom domain) is HTTPS on port 443, behind Railway's proxy.
if (getenv('RAILWAY_ENVIRONMENT_ID') !== false) {
    $values['http_port']            = '443';
    $values['force_ssl']            = 'true';
    $values['session_cookiesecure'] = '1';
}

$new = set_keys($text, $values);
if ($mode === '--new' || $new !== $text) {
    if (file_put_contents(CFG . '.tmp', $new) === false || !rename(CFG . '.tmp', CFG)) {
        fwrite(STDERR, "cannot write the config\n");
        exit(1);
    }
    chmod(CFG, 0660);
}
