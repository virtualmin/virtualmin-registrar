#!/usr/local/bin/perl
# Select existing contacts for a domain
use strict;
use warnings;
our (%text, %in);

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'contact_err'});

# Get the Virtualmin domain
&can_domain($in{'dom'}) || &error($text{'contact_ecannot'});
my $d = &virtual_server::get_domain_by("dom", $in{'dom'});
$d || &error(&text('contact_edom', $in{'dom'}));
&can_contacts($d) == 3 || &error(&text('contact_edom', $in{'dom'}));
my ($account) = grep { $_->{'id'} eq $d->{'registrar_account'} }
		  &list_registrar_accounts();
$account || &error(&text('contact_eaccount', $in{'dom'}));

# Create list of new contacts
my $lfunc = "type_".$account->{'registrar'}."_list_contacts";
my ($ok, $allcons) = &$lfunc($account);
$ok || &error($allcons);
my $cfunc = "type_".$account->{'registrar'}."_get_contact";
my $cons = &$cfunc($account, $d);
my @newcons;
foreach my $p (map { $_->{'purpose'} } @$cons) {
	my ($con) = grep { $_->{'id'} eq $in{$p} } @$allcons;
	$con || &error(&text('contact_efind', $in{$p}));
	$con->{'purpose'} = $p;
	push(@newcons, $con);
	}

# Call function to set
my $ufunc = "type_".$account->{'registrar'}."_update_contacts";
my $err = &$ufunc($account, $d, \@newcons);
&error($err) if ($err);

# Redirect to Virtualmin post-save page
&virtual_server::domain_redirect($d);
