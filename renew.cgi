#!/usr/local/bin/perl
# Actually perform domain renewal
use strict;
use warnings;
our (%text, %in);

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'renew_err'});

# Get the Virtualmin domain
&can_domain($in{'dom'}) && &virtual_server::can_use_feature($module_name) ||
	&error($text{'renew_ecannot'});
my $d = &virtual_server::get_domain_by("dom", $in{'dom'});
$d || &error(&text('contact_edom', $in{'dom'}));
my ($account) = grep { $_->{'id'} eq $d->{'registrar_account'} }
		  &list_registrar_accounts();
$account || &error(&text('contact_eaccount', $in{'dom'}));

# Validate inputs
$in{'years'} =~ /^\d+$/ && $in{'years'} > 0 && $in{'years'} <= 10 ||
	&error($text{'renew_eyears'});

# Do it
&ui_print_unbuffered_header(&virtual_server::domain_in($d),
			    $text{'renew_title'}, "", "renew");

print &text('renew_doing', "<tt>$d->{'dom'}</tt>", "<i>$account->{'desc'}</i>",
	    $in{'years'}),"<br>\n";
my $rfunc = "type_".$account->{'registrar'}."_renew_domain";
my ($ok, $msg) = &$rfunc($account, $d, $in{'years'});
if ($ok) {
	print &text('renew_done', $msg),"<p>\n";
	}
else {
	print &text('renew_failed', $msg),"<p>\n";
	}

&ui_print_footer();
