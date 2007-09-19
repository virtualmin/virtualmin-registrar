#!/usr/local/bin/perl
# Show contact details for some domain

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'cointact_err'});

# Get the Virtualmin domain
&can_domain($in{'dom'}) || &error($text{'contact_ecannot'});
$d = &virtual_server::get_domain_by("dom", $in{'dom'});
$d || &error(&text('contact_edom', $in{'dom'}));
($account) = grep { $_->{'id'} eq $d->{'registrar_account'} }
		  &list_registrar_accounts();
$account || &error(&text('contact_eaccount', $in{'dom'}));

# Get contact info from registrar
$cfunc = "type_".$account->{'registrar'}."_get_contact";
$cons = &$cfunc($account, $d);
ref($cons) || &error($cons);

&ui_print_header(&virtual_server::domain_in($d), $text{'contact_title'}, "");

print &ui_form_start("save_contact.cgi", "post");
print &ui_hidden("dom", $in{'dom'});

# Show fields for each contact type
foreach my $con (@$cons) {
	print &ui_hidden_table_start($text{'contact_header_'.$con->{'type'}},
				     "width=100%", 2, $con->{'type'}, 1,
				     [ "width=30%" ]);

	@schema = &get_contact_schema($account, $d, $con->{'type'});
	foreach my $s (@schema) {
		if ($s->{'opt'}) {
			$field = &ui_opt_textbox($s->{'name'},
				$con->{$s->{'name'}}, $s->{'size'},
				$text{'default'});
			}
		else {
			$field = &ui_textbox($s->{'name'},
				$con->{$s->{'name'}}, $s->{'size'});
			}
		print &ui_table_row($text{'contact_'.$s->{'name'},
			$field);
		}

	print &ui_hidden_table_end();
	}

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer();

