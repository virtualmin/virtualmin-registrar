use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'update_contacts.cgi' );
strict_ok( 'update_contacts.cgi' );
warnings_ok( 'update_contacts.cgi' );
