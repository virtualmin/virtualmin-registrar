#!/usr/local/bin/perl
# Select existing contacts for a domain

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'contact_err'});

# Get the Virtualmin domain
&can_domain($in{'dom'}) || &error($text{'contact_ecannot'});
$d = &virtual_server::get_domain_by("dom", $in{'dom'});
$d || &error(&text('contact_edom', $in{'dom'}));
&can_contacts($d) == 3 || &error(&text('contact_edom', $in{'dom'}));
($account) = grep { $_->{'id'} eq $d->{'registrar_account'} }
		  &list_registrar_accounts();
$account || &error(&text('contact_eaccount', $in{'dom'}));

# Create list of new contacts
$lfunc = "type_".$account->{'registrar'}."_list_contacts";
($ok, $allcons) = &$lfunc($account);
$ok || &error($allcons);
$cfunc = "type_".$account->{'registrar'}."_get_contact";
$cons = &$cfunc($account, $d);
foreach my $p (map { $_->{'purpose'} } @$cons) {
	local ($con) = grep { $_->{'id'} eq $in{$p} } @$allcons;
	$con || &error(&text('contact_efind', $in{$p}));
	$con->{'purpose'} = $p;
	push(@newcons, $con);
	}

# Call function to set
$ufunc = "type_".$account->{'registrar'}."_update_contacts";
$err = &$ufunc($account, $d, \@newcons);
&error($err) if ($err);

# Redirect to Virtualmin post-save page
&virtual_server::domain_redirect($d);
