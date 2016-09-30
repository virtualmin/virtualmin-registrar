#!/usr/local/bin/perl
# Request a domain transfer to a registrar account
use strict;
no strict 'refs';
use warnings;
our (%access, %text, %in);
our $module_name;

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'transfer_err'});
$access{'registrar'} || &error($text{'transfer_ecannot'});

# Get the Virtualmin domain and account
my $d = &virtual_server::get_domain_by("dom", $in{'dom'});
$d || &error(&text('contact_edom', $in{'dom'}));
$d->{$module_name} && &error($text{'import_ealready'});
my ($account) = grep { $_->{'id'} eq $in{'account'} }
		  &list_registrar_accounts();
$account || &error(&text('contact_eaccount', $in{'dom'}));

# Validate inputs
$in{'transfer'} =~ /\S/ || &error($text{'import_etransfer'});
$in{'years_def'} || $in{'years'} =~ /^\d+$/ ||
	&error($text{'renew_eyears'});

# Show progress
&ui_print_unbuffered_header(&virtual_server::domain_in($d),
			    $text{'transfer_title'}, "");

print $text{'transfer_transferring'},"<br>\n";
my $tfunc = "type_".$account->{'registrar'}."_transfer_domain";
my ($ok, $msg) = &$tfunc($account, $d, $in{'transfer'},
	$in{'years_def'} ? undef : $in{'years'});
if ($ok) {
	print &text('transfer_done', $msg),"<p>\n";
	print &text('transfer_done2', "edit_import.cgi?dom=$d->{'dom'}"),"<p>\n";
	$d->{'registrar_transferred'} = $msg;
	&virtual_server::save_domain($d);
	}
else {
	print &text('import_failed', $msg),"<p>\n";
	}

&ui_print_footer(&virtual_server::domain_footer_link($d));
