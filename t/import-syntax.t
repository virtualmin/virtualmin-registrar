use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'import.cgi' );
strict_ok( 'import.cgi' );
warnings_ok( 'import.cgi' );
