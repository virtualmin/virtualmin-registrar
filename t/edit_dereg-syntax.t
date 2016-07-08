use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_dereg.cgi' );
strict_ok( 'edit_dereg.cgi' );
warnings_ok( 'edit_dereg.cgi' );
