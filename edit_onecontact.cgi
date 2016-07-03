#!/usr/local/bin/perl
# Show a form to edit a single contact associated with a registrar
use strict;
use warnings;
our (%text, %in);
our $module_name;

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'onecontact_err'});

# Get the Virtualmin domain
my $d = &virtual_server::get_domain_by("dom", $in{'dom'});

# Get the account
my @accounts = &list_registrar_accounts();
my ($account) = grep { $_->{'id'} eq $in{'id'} } @accounts;
$account || &error($text{'contacts_eaccount'});

&ui_print_header($account->{'desc'},
		 $in{'new'} ? $text{'onecontact_create'}
			    : $text{'onecontact_edit'}, "");

my $cfunc = "type_".$account->{'registrar'}."_get_contact_classes";
my @classes = &$cfunc($account);
my $cls;
my $con;
if (!$in{'new'}) {
	# Get the contact
	$cfunc = "type_".$account->{'registrar'}."_list_contacts";
	my ($ok, $contacts) = &$cfunc($account);
	$ok || &error(&text('contacts_elist', $contacts));
	($con) = grep { $_->{'id'} eq $in{'cid'} } @$contacts;
	($cls) = grep { $con->{$_->{'field'}} eq $_->{'id'} } @classes;
	$in{'cls'} = $cls->{'id'} if ($cls);
	}
else {
	# Set type from class
	($cls) = grep { $_->{'id'} eq $in{'cls'} } @classes;
	if ($cls && $cls->{'field'}) {
		$con = { $cls->{'field'} => $cls->{'id'} };
		}
	}

&ui_print_header(undef, $text{'onecontact_title'}, "");

print &ui_form_start("save_onecontact.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &ui_hidden("cid", $in{'cid'});
print &ui_hidden("new", $in{'new'});
print &ui_hidden("cls", $in{'cls'});
print &ui_table_start(&text('onecontact_header', $cls->{'desc'}),
		      "width=100%", 2);

my @schema = &get_contact_schema($account, undef, undef, $in{'new'}, $in{'cls'});
foreach my $s (@schema) {
	my $n = $s->{'name'};
	my $field;
	if ($s->{'readonly'}) {
		# Just show value
		$field = $con->{$s->{'name'}};
		next if ($in{'new'} && !$field);
		if ($s->{'choices'}) {
			my ($c) = grep { $_->[0] eq $field } @{$s->{'choices'}};
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
	my $dfunc = "type_".$account->{'registrar'}."_delete_one_contact";
	print &ui_form_end([ [ undef, $text{'save'} ],
			     defined(&$dfunc) ?
				[ 'delete', $text{'delete'} ] : undef ]);
	}

&ui_print_footer(&virtual_server::domain_footer_link($d));
