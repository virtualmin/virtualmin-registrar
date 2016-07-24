use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'save_contact.cgi' );
strict_ok( 'save_contact.cgi' );
warnings_ok( 'save_contact.cgi' );
