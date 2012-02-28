#!/usr/local/bin/perl
# Create, update or delete one contact

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'onecontact_err'});

# Get the account
@accounts = &list_registrar_accounts();
($account) = grep { $_->{'id'} eq $in{'id'} } @accounts;
$account || &error($text{'contacts_eaccount'});

if (!$in{'new'}) {
	# Get the contacts
	$cfunc = "type_".$account->{'registrar'}."_list_contacts";
	($ok, $contacts) = &$cfunc($account);
	$ok || &error(&text('contacts_elist', $contacts));
	($con) = grep { $_->{'id'} eq $in{'cid'} } @$contacts;
	}
else {
	$con = { };
	}

if ($in{'delete'}) {
	# Remove the contact
	$dfunc = "type_".$account->{'registrar'}."_delete_one_contact";
	$err = &$dfunc($account, $con);
	&error(&text('onecontact_edelete', $err)) if ($err);
	}
else {
	# Validate all input types, and update object
	@schema = &get_contact_schema($account, $d, $con->{'type'});
	foreach my $s (@schema) {
		$n = $s->{'name'};
		$fn = $text{'contact_'.$s->{'name'}};
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
	if ($in{'new'}) {
		$sfunc = "type_".$account->{'registrar'}."_create_one_contact";
		}
	else {
		$sfunc = "type_".$account->{'registrar'}."_modify_one_contact";
		}
	$err = &$sfunc($account, $con);
	&error(&text('onecontact_esave', $err)) if ($err);
	}

# Return to contacts list
&redirect("list_contacts.cgi?id=$in{'id'}");

