#!/usr/local/bin/perl
# Show a form to edit a single contact associated with a registrar

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'onecontact_err'});

# Get the account
@accounts = &list_registrar_accounts();
($account) = grep { $_->{'id'} eq $in{'id'} } @accounts;
$account || &error($text{'contacts_eaccount'});

&ui_print_header($account->{'desc'}, $text{'contacts_title'}, "");

if (!$in{'new'}) {
	# Get the contacts
	$cfunc = "type_".$account->{'registrar'}."_list_contacts";
	($ok, $contacts) = &$cfunc($account);
	$ok || &error(&text('contacts_elist', $contacts));
	($con) = grep { $_->{'id'} eq $in{'cid'} } @$contacts;
	}

&ui_print_header(undef, $text{'onecontact_title'}, "");

print &ui_form_start("save_onecontact.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &ui_hidden("cid", $in{'cid'});
print &ui_hidden("new", $in{'new'});
print &ui_table_start($text{'onecontact_header'}, "width=100%", 2);

@schema = &get_contact_schema($account);
foreach my $s (@schema) {
	$n = $s->{'name'};
	if ($s->{'readonly'}) {
		# Just show value
		next if ($in{'new'});
		$field = $con->{$s->{'name'}};
		}
	elsif ($s->{'choices'}) {
		# Select from menu
		@choices = @{$s->{'choices'}};
		if ($s->{'opt'}) {
			unshift(@choices,
				[ undef, $text{'contact_default'} ]);
			}
		$field = &ui_select($n, $con->{$s->{'name'}},
				    \@choices, 1, 0, !$in{'new'});
		}
	elsif ($s->{'opt'} == 1) {
		# Optional value
		$field = &ui_opt_textbox($n,
			$con->{$s->{'name'}}, $s->{'size'},
			$text{'contact_default'});
		}
	else {
		# Required value
		$field = &ui_textbox($n,
			$con->{$s->{'name'}}, $s->{'size'});
		}
	print &ui_table_row($text{'contact_'.$s->{'name'}}, $field);
	}
print &ui_table_end();

if ($in{'new'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ 'delete', $text{'delete'} ] ]);
	}

&ui_print_footer(&virtual_server::domain_footer_link($d));

