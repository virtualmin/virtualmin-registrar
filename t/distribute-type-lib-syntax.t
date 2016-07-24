use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'distribute-type-lib.pl' );
strict_ok( 'distribute-type-lib.pl' );
warnings_ok( 'distribute-type-lib.pl' );
