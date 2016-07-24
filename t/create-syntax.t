use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'create.cgi' );
strict_ok( 'create.cgi' );
warnings_ok( 'create.cgi' );
