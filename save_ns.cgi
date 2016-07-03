#!/usr/local/bin/perl
# Update nameservers for some domain
use strict;
use warnings;
our (%text, %in);

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'ns_err'});

# Get the Virtualmin domain
&can_domain($in{'dom'}) || &error($text{'ns_ecannot'});
my $d = &virtual_server::get_domain_by("dom", $in{'dom'});
$d || &error(&text('contact_edom', $in{'dom'}));
&can_nameservers($d) || &error($text{'ns_ecannot'});
my ($account) = grep { $_->{'id'} eq $d->{'registrar_account'} }
		  &list_registrar_accounts();
$account || &error(&text('contact_eaccount', $in{'dom'}));
&virtual_server::obtain_lock_dns($d);

# Validate and parse inputs
my $nss;
if ($in{'same'}) {
	# Nameservers some from Virtualmin
	$nss = &get_domain_nameservers($account, $d);
	}
else {
	$nss = [ split(/\s+/, $in{'ns'}) ];
	@$nss || &error($text{'ns_enone'});
	foreach my $ns (@$nss) {
		&check_ipaddress($ns) && &error(&text('ns_eip', $ns));
		&to_ipaddress($ns) || &error(&text('ns_ens', $ns));
		}
	}

&ui_print_unbuffered_header(&virtual_server::domain_in($d),
			    $text{'ns_title'}, "");

# Update registrar
&$virtual_server::first_print(
	&text('ns_reg', join(" , ", map { "<tt>$_</tt>" } @$nss)));
my $sfunc = "type_".$account->{'registrar'}."_set_nameservers";
my $err = &$sfunc($account, $d, $nss);
if ($err) {
	&$virtual_server::second_print(&text('ns_failed', $err));
	}
else {
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	}

# Update BIND zone, if requested
if ($in{'sync'} && !$err) {
	&$virtual_server::first_print($text{'ns_syncing'});
	&set_domain_nameservers($d, $nss);
	&$virtual_server::second_print($virtual_server::text{'setup_done'});
	}

&virtual_server::release_lock_dns($d);
&virtual_server::run_post_actions();
&ui_print_footer(&virtual_server::domain_footer_link($d));
