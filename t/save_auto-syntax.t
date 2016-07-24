use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_auto.cgi' );
strict_ok( 'save_auto.cgi' );
warnings_ok( 'save_auto.cgi' );
