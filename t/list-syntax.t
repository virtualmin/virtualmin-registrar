use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'list.cgi' );
strict_ok( 'list.cgi' );
warnings_ok( 'list.cgi' );
