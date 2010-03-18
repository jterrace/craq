#!/opt/local/bin/perl

use BerkeleyDB ;


print "Content-type: text/plain\n\n";

$request_method = $ENV{'REQUEST_METHOD'};
$request_uri = substr($ENV{'REQUEST_URI'}, 1);
$content_length = $ENV{'CONTENT_LENGTH'};

my $filename = "database";

if (!(-e $filename)) {
	exec('>' . $filename);	
}

if ($request_method eq 'GET') {
	
	my %hash;
	tie %hash, 'BerkeleyDB::Hash',
	            -Filename  => $filename,
	            -Flags     => DB_RDONLY
	    or die "Cannot open file $filename: $! $BerkeleyDB::Error\n" ;
	
	print $hash{$request_uri};
	untie %hash ;
	
} elsif ($request_method eq 'PUT') {
	
	read(STDIN, $buffer, $content_length);
	my %hash ;
	tie %hash, 'BerkeleyDB::Hash',
	            -Filename  => $filename
	    or die "Cannot open file $filename: $! $BerkeleyDB::Error\n" ;
	
	$hash{$request_uri} = $buffer;
	untie %hash ;
	
} elsif ($request_method eq 'DELETE') {
	
	my %hash;
	tie %hash, 'BerkeleyDB::Hash',
	            -Filename  => $filename
	    or die "Cannot open file $filename: $! $BerkeleyDB::Error\n" ;
	
	$hash{$request_uri} = '';
	untie %hash ;
	
} else {
	print 'unrecognized request method: ' . $request_method;
}
