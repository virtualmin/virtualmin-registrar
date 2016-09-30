#!/usr/local/bin/perl
# Update contact details for some domain
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
&can_contacts($d) == 1 || &can_contacts($d) == 3 ||
	&error(&text('contact_edom', $in{'dom'}));
my ($account) = grep { $_->{'id'} eq $d->{'registrar_account'} }
		  &list_registrar_accounts();
$account || &error(&text('contact_eaccount', $in{'dom'}));

# Get contact info from registrar
my $cfunc = "type_".$account->{'registrar'}."_get_contact";
my $cons = &$cfunc($account, $d);
ref($cons) || &error($cons);

# Validate all input types, and update object
foreach my $con (@$cons) {
	if ($in{$con->{'purpose'}."same"}) {
		# Same as first one
		my $ot = $con->{'purpose'};
		%$con = %{$cons->[0]};
		$con->{'purpose'} = $ot;
		next;
		}
	my @schema = &get_contact_schema($account, $d, $con->{'purpose'});
	foreach my $s (@schema) {
		my $n = $con->{'purpose'}.$s->{'name'};
		my $fn = $text{'contact_'.lc($s->{'name'})};
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
	}

# Save the contact
my $sfunc = "type_".$account->{'registrar'}."_save_contact";
my $err = &$sfunc($account, $d, $cons);
&error(&text('contact_esave', $err)) if ($err);

# Redirect to Virtualmin post-save page
&virtual_server::domain_redirect($d);
