use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save.cgi' );
strict_ok( 'save.cgi' );
warnings_ok( 'save.cgi' );
