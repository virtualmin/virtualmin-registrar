use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'delete.cgi' );
strict_ok( 'delete.cgi' );
warnings_ok( 'delete.cgi' );
