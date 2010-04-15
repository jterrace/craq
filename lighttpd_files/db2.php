<?php

$request_method = $_ENV['REQUEST_METHOD'];
$request_uri = substr($_ENV['REQUEST_URI'], 1);
$content_length = $_ENV['CONTENT_LENGTH'];

$filename = "/tmp/data.db";

if ($request_method === 'GET') {

	$id = dba_popen($filename, "r", "cdb");
	$val = dba_fetch($request_uri, $id);
	echo $val;
        
} else if ($request_method === 'PUT') {
        
	$buffer = file_get_contents('php://input');
	#$id = dba_popen($filename, "c", "gdbm");
	#dba_insert($request_uri, $buffer, $id);
	
} else if ($request_method === 'DELETE') {

	#$id = dba_popen($filename, "w", "gdbm");
	#dba_delete($request_uri, $id);

}

?>
