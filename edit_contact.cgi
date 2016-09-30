#!/usr/local/bin/perl
# Show a form to edit contact details for some domain
use strict;
no strict 'refs';
use warnings;
our (%text, %in);

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'contact_err'});

# Get the Virtualmin domain
&can_domain($in{'dom'}) || &error($text{'contact_ecannot'});
my $d = &virtual_server::get_domain_by("dom", $in{'dom'});
$d || &error(&text('contact_edom', $in{'dom'}));
&can_contacts($d) == 1 || can_contacts($d) == 3 ||
	&error(&text('contact_edom', $in{'dom'}));
my ($account) = grep { $_->{'id'} eq $d->{'registrar_account'} }
		  &list_registrar_accounts();
$account || &error(&text('contact_eaccount', $in{'dom'}));

# Get contact info from registrar
my $cfunc = "type_".$account->{'registrar'}."_get_contact";
my $cons = &$cfunc($account, $d);
ref($cons) || &error($cons);

&ui_print_header(&virtual_server::domain_in($d), $text{'contact_title'}, "",
		 "contact");

my $lfunc = "type_".$account->{'registrar'}."_list_contacts";
my $tabbed;
if (can_contacts($d) == 3 && defined(&$lfunc)) {
	# Start of tabs for contact selection mode
	my @tabs = ( [ 'create', $text{'contact_createtab'} ],
		  [ 'select', $text{'contact_selecttab'} ] );
	print &ui_tabs_start(\@tabs, 'mode', $in{'mode'} || 'create', 1);
	$tabbed = 1;
	}

# Start section for new contact creation
print &ui_tabs_start_tab('mode', 'create') if ($tabbed);
print &ui_form_start("save_contact.cgi", "post");
print &ui_hidden("dom", $in{'dom'});

# Show fields for each contact type
my $count;
foreach my $con (@$cons) {
	# Is this the same as the first one?
	my $same = undef;
	if ($con ne $cons->[0]) {
		$same = &contact_hash_to_string($cons->[0]) eq
			&contact_hash_to_string($con) ? 1 : 0;
		}

	print &ui_hidden_table_start($text{'contact_header_'.
					   lc($con->{'purpose'})} ||
					$con->{'purpose'},
				     "width=100%", 2, $con->{'purpose'}, !$same,
				     [ "width=30%" ]);
	if (defined($same)) {
		# Show option to make same as first
		print &ui_table_row($text{'contact_same'},
			&ui_yesno_radio($con->{'purpose'}.'same', $same));
		print &ui_table_hr();
		}

	if ($count++ == 0) {
		# Show registrar account
		print &ui_table_row($text{'ns_account'},
				    $account->{'desc'});
		}

	my @schema = &get_contact_schema($account, $d, $con->{'purpose'});
	foreach my $s (@schema) {
		my $field;
		my $n = $con->{'purpose'}.$s->{'name'};
		if ($s->{'readonly'}) {
			# Just show value
			$field = $con->{$s->{'name'}};
			if ($s->{'choices'}) {
				my ($c) = grep { $_->[0] eq $field }
					    @{$s->{'choices'}};
				$field = $c->[1] if ($c);
				}
			}
		elsif ($s->{'choices'}) {
			# Select from menu
			my @choices = @{$s->{'choices'}};
			if ($s->{'opt'}) {
				unshift(@choices,
					[ undef, $text{'contact_default'} ]);
				}
			$field = &ui_select($n, $con->{$s->{'name'}},
					    \@choices, 1, 0, 1);
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
		print &ui_table_row($text{'contact_'.lc($s->{'name'})}, $field);
		}

	print &ui_hidden_table_end();
	}

print &ui_form_end([ [ "save", $text{'save'} ] ]);
print &ui_tabs_end_tab('mode', 'create') if ($tabbed);

if ($tabbed) {
	# Start section for existing contact selection
	print &ui_tabs_start_tab('mode', 'select');
	print &ui_form_start("update_contacts.cgi", "post");
	print &ui_hidden("dom", $in{'dom'});
	print &ui_table_start($text{'contact_sheader'}, undef, 2);

	# Find all contacts the account has
	my ($ok, $allcons) = &$lfunc($account);
	print &ui_table_row($text{'ns_account'},
			    $account->{'desc'});

	# Show selector for each contact type for the domain
	foreach my $con (@$cons) {
		print &ui_table_row(
			$text{'contact_header_'.lc($con->{'purpose'})} ||
			    $con->{'purpose'},
			&ui_select($con->{'purpose'}, $con->{'id'},
			    [ map { [ $_->{'id'},
				      &nice_contact_name($_, $account,) ] }
				  @$allcons ]));
		}

	print &ui_table_end();
	print &ui_form_end([ [ undef, $text{'save'} ] ]);
	print &ui_tabs_end_tab('mode', 'select');
	print &ui_tabs_end(1);
	}

&ui_print_footer(&virtual_server::domain_footer_link($d));
