use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'transfer.cgi' );
strict_ok( 'transfer.cgi' );
warnings_ok( 'transfer.cgi' );
