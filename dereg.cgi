#!/usr/local/bin/perl
# Dis-associate a domain registration with this server
use strict;
no strict 'refs';
use warnings;
our (%access, %text, %in);
our $module_name;

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'dereg_err'});
$access{'registrar'} || &error($text{'import_ecannot'});

# Get the Virtualmin domain
my $d = &virtual_server::get_domain_by("dom", $in{'dom'});
$d || &error(&text('contact_edom', $in{'dom'}));
$d->{$module_name} || &error($text{'dereg_ealready'});
my ($account) = grep { $_->{'id'} eq $d->{'registrar_account'} }
		  &list_registrar_accounts();
$account || &error(&text('contact_eaccount', $in{'dom'}));

&ui_print_header(&virtual_server::domain_in($d), $text{'dereg_title'}, "",
		 "dereg");

# Do it
print &text('dereg_doing', "<i>$account->{'desc'}</i>"),"<br>\n";
$d->{$module_name} = 0;
delete($d->{'registrar_account'});
delete($d->{'registrar_id'});
&virtual_server::save_domain($d);
no warnings "once";
print $virtual_server::text{'setup_done'},"<p>\n";
use warnings "once";

# Update the Webmin user
&virtual_server::refresh_webmin_user($d);
&virtual_server::run_post_actions();

# Call any theme post command
if (defined(&theme_post_save_domain)) {
	&theme_post_save_domain($d, 'modify');
	}

&ui_print_footer(&virtual_server::domain_footer_link($d));
