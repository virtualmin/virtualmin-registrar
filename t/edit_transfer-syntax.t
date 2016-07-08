use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_transfer.cgi' );
strict_ok( 'edit_transfer.cgi' );
warnings_ok( 'edit_transfer.cgi' );
