#!/opt/local/bin/perl

use BerkeleyDB ;

print "Content-type: text/plain\n\n";

$request_method = $ENV{'REQUEST_METHOD'};
$request_uri = substr($ENV{'REQUEST_URI'}, 1);
$content_length = $ENV{'CONTENT_LENGTH'};

my $filename = "database";
my $errorlog = "dberror";

sub hash
{
	my ($data) = shift ;
	return $data ;
}


if ($request_method eq 'GET') {

	$db = new BerkeleyDB::Hash( -Filename => $filename,
				    -Flags => DB_RDONLY,
				    -Hash => \&hash) or die "Cannot open file $filename";
	$db->db_get($request_uri, $val);
	print $val;	
	
} elsif ($request_method eq 'PUT') {
	
	read(STDIN, $buffer, $content_length);
	if (!(-e $filename)) {
		$db = new BerkeleyDB::Hash( -Filename => $filename,
					    -Flags => DB_CREATE,
					    -Hash => \&hash) or die "Cannot open file $filename";
        } else {
		$db = new BerkeleyDB::Hash( -Filename => $filename,
					    -Hash => \&hash) or die "Cannot open file $filename";
	}
	$db->db_put($request_uri, $buffer);

} elsif ($request_method eq 'DELETE') {

	$db = new BerkeleyDB::Hash( -Filename => $filename,
				    -Hash => \&hash) or die "Cannot open file $filename";
        $db->db_del($request_uri);

} else {
	exec('echo ' . '"unrecognized request method: ' . $request_method . '" > ' . $errorlog);
}
