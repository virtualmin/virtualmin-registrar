#!/usr/local/bin/perl
# Show a form for associating a domain registration with this server

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'import_err'});
$access{'registrar'} || &error($text{'import_ecannot'});

# Get the Virtualmin domain
$d = &virtual_server::get_domain_by("dom", $in{'dom'});
$d || &error(&text('contact_edom', $in{'dom'}));
$d->{$module_name} && &error($text{'import_ealready'});

&ui_print_header(&virtual_server::domain_in($d), $text{'import_title'}, "",
		 "import");

print &ui_form_start("import.cgi", "post");
print &ui_hidden("dom", $in{'dom'});
print &ui_table_start($text{'import_header'}, undef, 2);

# Account it will be under
@accounts = &list_registrar_accounts();
$def = &find_registrar_account($d->{'dom'});
print &ui_table_row($text{'import_account'},
	&ui_select("account", $def ? $def->{'id'} : undef,
		[ map { [ $_->{'id'}, $_->{'desc'} ] } @accounts ]));

# Registrar ID
print &ui_table_row($text{'import_id'},
	&ui_opt_textbox("id", undef, 20, $text{'import_auto'}));

# Update nameservers?
print &ui_table_row($text{'import_ns'},
	&ui_yesno_radio("ns", 0));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'import_ok'} ] ]);

&ui_print_footer(&virtual_server::domain_footer_link($d));

