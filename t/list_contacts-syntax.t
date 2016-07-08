use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'list_contacts.cgi' );
strict_ok( 'list_contacts.cgi' );
warnings_ok( 'list_contacts.cgi' );
