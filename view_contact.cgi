#!/usr/local/bin/perl
# Show contact details for some domain

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'contact_err'});

# Get the Virtualmin domain
&can_domain($in{'dom'}) || &error($text{'contact_ecannot'});
$d = &virtual_server::get_domain_by("dom", $in{'dom'});
$d || &error(&text('contact_edom', $in{'dom'}));
&can_contacts($d) || &error(&text('contact_edom', $in{'dom'}));
($account) = grep { $_->{'id'} eq $d->{'registrar_account'} }
		  &list_registrar_accounts();
$account || &error(&text('contact_eaccount', $in{'dom'}));

# Get contact info from registrar
$cfunc = "type_".$account->{'registrar'}."_get_contact";
$cons = &$cfunc($account, $d);
ref($cons) || &error($cons);

&ui_print_header(&virtual_server::domain_in($d), $text{'contact_title2'}, "");

# Show fields for each contact type
foreach my $con (@$cons) {
	print &ui_hidden_table_start($text{'contact_header_'.
					   lc($con->{'purpose'})},
				     "width=100%", 2, $con->{'type'}, !$same,
				     [ "width=30%" ]);

	@schema = &get_contact_schema($account, $d, $con->{'type'});
	foreach my $s (@schema) {
		$v = $con->{$s->{'name'}};
		if ($s->{'choices'}) {
			($ch) = grep { $_->[0] eq $v } @{$s->{'choices'}};
			$v = $ch->[1] if ($ch);
			}
		print &ui_table_row($text{'contact_'.lc($s->{'name'})}, $v);
		}

	print &ui_hidden_table_end();
	}

&ui_print_footer();

