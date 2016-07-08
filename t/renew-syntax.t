use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'renew.cgi' );
strict_ok( 'renew.cgi' );
warnings_ok( 'renew.cgi' );
