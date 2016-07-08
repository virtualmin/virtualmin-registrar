use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_ns.cgi' );
strict_ok( 'edit_ns.cgi' );
warnings_ok( 'edit_ns.cgi' );
