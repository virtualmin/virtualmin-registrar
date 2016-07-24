use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_renew.cgi' );
strict_ok( 'edit_renew.cgi' );
warnings_ok( 'edit_renew.cgi' );
