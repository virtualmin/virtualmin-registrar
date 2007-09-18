#!/usr/local/bin/perl
# Show a list of registered domains accessible to the current user

require 'virtualmin-registrar-lib.pl';
&ui_print_header(undef, $text{'list_title'}, "");

# XXX

&ui_print_footer("/", $text{'index'});
