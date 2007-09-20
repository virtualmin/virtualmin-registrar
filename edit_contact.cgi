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
	# Is this the same as the first one?
	$same = undef;
	if ($con ne $cons->[0]) {
		local @fk = sort { $a cmp $b } grep { $_ ne "type" } (keys %{$cons->[0]});
		local @k = sort { $a cmp $b } grep { $_ ne "type" } (keys %$con);
		local $fj = join(" ", map { $_."=".$cons->[0]->{$_} } @fk);
		local $j = join(" ", map { $_."=".$con->{$_} } @fk);
		$same = $fj eq $j ? 1 : 0;
		}

	print &ui_hidden_table_start($text{'contact_header_'.$con->{'type'}},
				     "width=100%", 2, $con->{'type'}, !$same,
				     [ "width=30%" ]);
	if (defined($same)) {
		# Show option to make same as first
		# XXX disable inputs?
		print &ui_table_row($text{'contact_same'},
			&ui_yesno_radio($con->{'type'}.'same', $same));
		print &ui_table_hr();
		}

	@schema = &get_contact_schema($account, $d, $con->{'type'});
	foreach my $s (@schema) {
		$n = $con->{'type'}.$s->{'name'};
		if ($s->{'choices'}) {
			@choices = @{$s->{'choices'}};
			if ($s->{'opt'}) {
				unshift(@choices,
					[ undef, $text{'contact_default'} ]);
				}
			$field = &ui_select($n, $con->{$s->{'name'}},
					    \@choices);
			}
		elsif ($s->{'opt'} == 1) {
			$field = &ui_opt_textbox($n,
				$con->{$s->{'name'}}, $s->{'size'},
				$text{'contact_default'});
			}
		else {
			$field = &ui_textbox($n,
				$con->{$s->{'name'}}, $s->{'size'});
			}
		print &ui_table_row($text{'contact_'.$s->{'name'}}, $field);
		}

	print &ui_hidden_table_end();
	}

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer();

