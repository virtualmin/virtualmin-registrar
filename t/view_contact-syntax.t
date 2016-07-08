use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'view_contact.cgi' );
strict_ok( 'view_contact.cgi' );
warnings_ok( 'view_contact.cgi' );
