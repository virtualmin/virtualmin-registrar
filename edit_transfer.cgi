#!/usr/local/bin/perl
# Show a form for initiating a domain transfer

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'transfer_err'});
$access{'registrar'} || &error($text{'transfer_ecannot'});

# Get the Virtualmin domain
$d = &virtual_server::get_domain_by("dom", $in{'dom'});
$d || &error(&text('contact_edom', $in{'dom'}));
$d->{$module_name} && &error($text{'import_ealready'});

&ui_print_header(&virtual_server::domain_in($d), $text{'transfer_title'}, "",
		 "transfer");

print &ui_form_start("transfer.cgi", "post");
print &ui_hidden("dom", $in{'dom'});
print &ui_table_start($text{'transfer_header'}, undef, 2);

# Account it will be under
@accounts = grep { $tfunc = "type_".$_->{'registrar'}."_transfer_domain";
		   defined(&$tfunc) } &list_registrar_accounts();
$def = &find_registrar_account($d->{'dom'});
print &ui_table_row($text{'transfer_account'},
	&ui_select("account", $def ? $def->{'id'} : undef,
		[ map { [ $_->{'id'}, $_->{'desc'} ] } @accounts ]));

# Transfer key
print &ui_table_row($text{'transfer_key'},
	&ui_textbox("transfer", undef, 30));

# Optional renewal period
print &ui_table_row($text{'import_renew'},
	&ui_opt_textbox("years", undef, 5, $text{'no'},
			$text{'import_renewyes'})." ".
	$text{'feat_periodyears'});

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'transfer_ok'} ] ]);

&ui_print_footer(&virtual_server::domain_footer_link($d));

