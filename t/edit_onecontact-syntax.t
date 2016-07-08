use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_onecontact.cgi' );
strict_ok( 'edit_onecontact.cgi' );
warnings_ok( 'edit_onecontact.cgi' );
