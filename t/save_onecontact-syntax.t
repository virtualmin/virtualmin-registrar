use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_onecontact.cgi' );
strict_ok( 'save_onecontact.cgi' );
warnings_ok( 'save_onecontact.cgi' );
