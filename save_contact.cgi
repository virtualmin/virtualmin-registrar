#!/usr/local/bin/perl
# Update contact details for some domain

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'contact_err'});

# Get the Virtualmin domain
&can_domain($in{'dom'}) || &error($text{'contact_ecannot'});
$d = &virtual_server::get_domain_by("dom", $in{'dom'});
$d || &error(&text('contact_edom', $in{'dom'}));
&can_contacts($d) == 1 || &error(&text('contact_edom', $in{'dom'}));
($account) = grep { $_->{'id'} eq $d->{'registrar_account'} }
		  &list_registrar_accounts();
$account || &error(&text('contact_eaccount', $in{'dom'}));

# Get contact info from registrar
$cfunc = "type_".$account->{'registrar'}."_get_contact";
$cons = &$cfunc($account, $d);
ref($cons) || &error($cons);

# Validate all input types, and update object
foreach my $con (@$cons) {
	if ($in{$con->{'type'}."same"}) {
		# Same as first one
		$ot = $con->{'type'};
		%$con = %{$cons->[0]};
		$con->{'type'} = $ot;
		next;
		}
	@schema = &get_contact_schema($account, $d, $con->{'type'});
	foreach my $s (@schema) {
		$n = $con->{'type'}.$s->{'name'};
		$fn = $text{'contact_'.$s->{'name'}};
		if ($s->{'choices'}) {
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
	}

# Save the contact
$sfunc = "type_".$account->{'registrar'}."_save_contact";
$err = &$sfunc($account, $d, $cons);
&error(&text('contact_esave', $err)) if ($err);

# Redirect to Virtualmin post-save page
&virtual_server::domain_redirect($d);

