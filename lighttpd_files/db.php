<?php

$request_method = $_ENV['REQUEST_METHOD'];
$request_uri = substr($_ENV['REQUEST_URI'], 1);
$content_length = $_ENV['CONTENT_LENGTH'];

$filename = "database";

$db = new Db4();

if ($request_method === 'GET') {

	$db->open(NULL, $filename, NULL);
	$val = $db->get($request_uri);
	echo $val;
        
} else if ($request_method === 'PUT') {
        
	$buffer = file_get_contents('php://input');
	$db->open(NULL, $filename, NULL, DB_CREATE);
	$db->put($request_uri, $buffer);
	
} else if ($request_method === 'DELETE') {

	$db->open(NULL, $filename, NULL);
	$db->del($request_uri);

}

?>
