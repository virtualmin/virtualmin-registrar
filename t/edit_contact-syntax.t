use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'edit_contact.cgi' );
strict_ok( 'edit_contact.cgi' );
warnings_ok( 'edit_contact.cgi' );
