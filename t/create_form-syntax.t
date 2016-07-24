use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'create_form.cgi' );
strict_ok( 'create_form.cgi' );
warnings_ok( 'create_form.cgi' );
