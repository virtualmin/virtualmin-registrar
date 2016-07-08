use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'auto.pl' );
strict_ok( 'auto.pl' );
warnings_ok( 'auto.pl' );
