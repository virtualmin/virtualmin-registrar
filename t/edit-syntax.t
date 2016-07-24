use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit.cgi' );
strict_ok( 'edit.cgi' );
warnings_ok( 'edit.cgi' );
