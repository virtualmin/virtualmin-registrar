use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'dereg.cgi' );
strict_ok( 'dereg.cgi' );
warnings_ok( 'dereg.cgi' );
