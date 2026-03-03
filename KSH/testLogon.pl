#!/app/perl/perl5_64/bin/perl

use DBI ;

$n = "\n" ;

$ora_conn     = $ENV{"ORA_CONN"}             || die  "\$ORA_CONN not set in enviroment." ;
$ora_user      = $ENV{"ORA_USER"}             || die  "\$ORA_USER not set in enviroment." ;
$ora_pwd      = $ENV{"ORA_PWD"}              || die "\$ORA_PWD not set in environment." ;


print "About to connect to Oracle\n";
my $db = undef ;
$db = DBI->connect ($ora_conn, $ora_user, $ora_pwd) ;
if ($db eq undef) {
    die ("Could not connect to Oracle: " . $DBI::errstr . $n) ;
}
$db->{AutoCommit} = 0 ;
#$db->{PrintError} = 0 ; # Suppress error messages being sent to STDOUT
#$db->{RaiseError} = 0 ; # Manual error handling
print "Connected to Oracle." . $n ;


my $stmt = undef ;
my $myerr = undef ;
my @oracle_data = () ;

eval {
   $stmt = $db->prepare ("SELECT SYSDATE FROM DUAL") ;
} ; # End eval
$stmt->finish ;

unless ($stmt->execute) {
    $myerr = $stmt->errstr ;
    print "Error was " . $myerr . $n ;
}

while (@oracle_data = $stmt -> fetchrow_array ()) {
    print "SYSDATE was $oracle_data[0]" . $n;
}

print "About to disconnect\n";
$db->disconnect ;

