#!/usr/local/bin/perl
# Show a form for creating a new registrar account
use strict;
no strict 'refs';
use warnings;
our (%access, %text, %in);
our $account;

require './virtualmin-registrar-lib.pl';
$access{'registrar'} || &error($text{'create_ecannot'});
&ReadParse();
&ui_print_header(undef, $text{'create_title'}, "", "create");
my $reg = $in{'registrar'};

print &ui_form_start("create.cgi", "post");
print &ui_hidden("registrar", $in{'registrar'});
print &ui_table_start($text{'create_header'}, undef, 2);

# Registrar type
my $dfunc = "type_".$reg."_desc";
print &ui_table_row($text{'edit_registrar'}, &$dfunc($account));

# Description
print &ui_table_row($text{'edit_desc'},
	&ui_textbox("desc", $account->{'desc'}, 60));

# Registrar-specific inputs
my $cfunc = "type_".$reg."_create_inputs";
print &$cfunc();

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'create'} ] ]);

&ui_print_footer("", $text{'index_return'});
