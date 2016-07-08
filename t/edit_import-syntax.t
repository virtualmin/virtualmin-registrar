use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_import.cgi' );
strict_ok( 'edit_import.cgi' );
warnings_ok( 'edit_import.cgi' );
