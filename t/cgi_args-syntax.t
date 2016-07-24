use Test::Strict tests => 3;                      # last test to print

syntax_ok( 'cgi_args.pl' );
strict_ok( 'cgi_args.pl' );
warnings_ok( 'cgi_args.pl' );
