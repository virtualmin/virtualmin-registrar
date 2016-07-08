use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_auto.cgi' );
strict_ok( 'edit_auto.cgi' );
warnings_ok( 'edit_auto.cgi' );
