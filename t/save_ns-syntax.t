use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_ns.cgi' );
strict_ok( 'save_ns.cgi' );
warnings_ok( 'save_ns.cgi' );
