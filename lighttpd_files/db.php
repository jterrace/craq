<?php

session_name("s");
session_start();

if (empty($_SESSION['count'])) {
	$_SESSION['count'] = 1;
} else {
	$_SESSION['count']++;
}

$request_method = $_ENV['REQUEST_METHOD'];
$request_uri = substr($_ENV['REQUEST_URI'], 1);
$content_length = $_ENV['CONTENT_LENGTH'];

$filename = "database";

$db = new Db4();

if ($request_method === 'GET') {

	if (!empty($_SESSION[$request_uri])) {
		echo $_SESSION[$request_uri];
	} else {
		$db->open(NULL, $filename, NULL);
		$val = $db->get($request_uri);
		echo $val;
	}
        
} else if ($request_method === 'PUT') {
        
	$buffer = file_get_contents('php://input');
	$_SESSION[$request_uri] = $buffer;
	
} else if ($request_method === 'DELETE') {

	unset($_SESSION[$request_uri]);
	$db->open(NULL, $filename, NULL);
	$db->del($request_uri);

}

if ($_SESSION['count'] > 100) {
	unset($_SESSION['count']);
	$db->open(NULL, $filename, NULL, DB_CREATE);
	foreach ($_SESSION as $key => $value) {
        	$db->put($key, $value);
	}
}

?>
