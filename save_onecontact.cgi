#!/usr/local/bin/perl
# Create, update or delete one contact
use strict;
use warnings;
our (%text, %in);

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'onecontact_err'});

# Get the account
my @accounts = &list_registrar_accounts();
my ($account) = grep { $_->{'id'} eq $in{'id'} } @accounts;
$account || &error($text{'contacts_eaccount'});

my $con;
if (!$in{'new'}) {
	# Get the contacts
	my $cfunc = "type_".$account->{'registrar'}."_list_contacts";
	my ($ok, $contacts) = &$cfunc($account);
	$ok || &error(&text('contacts_elist', $contacts));
	($con) = grep { $_->{'id'} eq $in{'cid'} } @$contacts;
	}
else {
	# Set type from class
	my $cfunc = "type_".$account->{'registrar'}."_get_contact_classes";
	my ($cls) = grep { $_->{'id'} eq $in{'cls'} } &$cfunc($account);
	if ($cls && $cls->{'field'}) {
		$con = { $cls->{'field'} => $cls->{'id'} };
		}
	}

if ($in{'delete'}) {
	# Remove the contact
	my $dfunc = "type_".$account->{'registrar'}."_delete_one_contact";
	my $err = &$dfunc($account, $con);
	&error(&text('onecontact_edelete', $err)) if ($err);
	}
else {
	# Validate all input types, and update object
	my @schema = &get_contact_schema($account, undef, undef, $in{'new'}, $in{'cls'});
	foreach my $s (@schema) {
		my $n = $s->{'name'};
		my $fn = $text{'contact_'.$s->{'name'}};
		if ($s->{'readonly'}) {
			# No need to save
			next;
			}
		elsif ($s->{'choices'}) {
			# Menu of choices
			$con->{$s->{'name'}} = $in{$n};
			}
		elsif ($s->{'opt'} == 1) {
			# Optional value with default
			if ($in{$n."_def"}) {
				$con->{$s->{'name'}} = "";
				}
			else {
				$in{$n} =~ /\S/ ||
					&error(&text('contact_emissing', $fn));
				$con->{$s->{'name'}} = $in{$n};
				}
			}
		elsif ($s->{'opt'} == 2) {
			# Optional value
			$con->{$s->{'name'}} = $in{$n};
			}
		else {
			# Mandatory value
			$in{$n} =~ /\S/ ||
				&error(&text('contact_emissing', $fn));
			$con->{$s->{'name'}} = $in{$n};
			}
		}

	# Save the contact
	my $sfunc;
	if ($in{'new'}) {
		$sfunc = "type_".$account->{'registrar'}."_create_one_contact";
		}
	else {
		$sfunc = "type_".$account->{'registrar'}."_modify_one_contact";
		}
	my $err = &$sfunc($account, $con);
	&error(&text('onecontact_esave', $err)) if ($err);
	}

# Return to contacts list
&redirect("list_contacts.cgi?id=$in{'id'}");
