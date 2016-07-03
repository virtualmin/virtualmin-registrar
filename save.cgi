#!/usr/local/bin/perl
# Create, update or delete a registrar account
use strict;
use warnings;
our (%access, %text, %in);
our $registrar_accounts_dir;

require './virtualmin-registrar-lib.pl';
$access{'registrar'} || &error($text{'edit_ecannot'});
&ReadParse();
&error_setup($text{'save_err'});
my @accounts = &list_registrar_accounts();

# Get the account object and registrar type
my $account;
my $reg;
if ($in{'registrar'}) {
	$reg = $in{'registrar'};
	$account = { 'id' => time().$$,
		     'registrar' => $reg };
	}
else {
	($account) = grep { $_->{'id'} eq $in{'id'} } @accounts;
	$account || &error($text{'edit_egone'});
	$reg = $account->{'registrar'};
	}

if ($in{'delete'}) {
	# Check if in use by any Virtualmin domains - if so, we can't delete
	&error_setup($text{'save_err2'});
	my @doms = &find_account_domains($account);
	if (@doms && @accounts < 2) {
		&error(&text('save_edoms',
			join(" ", map { "<tt>$_->{'dom'}</tt>" } @doms)));
		}

	if ($in{'confirm'}) {
		# Just delete it
		&lock_file($account->{'file'});
		&delete_registrar_account($account);
		&unlock_file($account->{'file'});

		# Update domains to new use registrar
		foreach my $d (@doms) {
			$d->{'registrar_account'} = $in{'transfer'};
			&virtual_server::save_domain($d);
			}
		}
	else {
		# Ask first
		&ui_print_header(undef, $text{'save_dtitle'}, "");
		print &ui_form_start("save.cgi", "post");
		print &ui_hidden("id", $in{'id'});
		print &ui_hidden("delete", 1);
		print "<center>";
		print &text('save_drusure',
			    "<i>$account->{'desc'}</i>"),"<p>\n",
		      &ui_submit($text{'save_dok'}, 'confirm'),"<p>\n";

		# Ask which account to transfer to
		if (@doms) {
			print "<b>",&text('save_transfer', scalar(@doms))," ",
			      &ui_select("transfer", undef,
				[ map { [ $_->{'id'}, $_->{'desc'} ] }
				      grep { $_->{'id'} ne $account->{'id'} }
					   @accounts ]),"</b><p>\n";
			}

		print "</center>\n";
		print &ui_form_end();
		&ui_print_footer("", $text{'index_return'});
		}
	}
else {
	# Validate inputs
	$in{'desc'} =~ /\S/ || &error($text{'save_edesc'});
	$account->{'desc'} = $in{'desc'};
	$account->{'enabled'} = $in{'enabled'};
	if ($in{'doms_def'}) {
		delete($account->{'doms'});
		}
	else {
		$in{'doms'} =~ /\S/ || &error($text{'save_etopdoms'});
		foreach my $tld (split(/\s+/, $in{'doms'})) {
			$tld =~ /^\.[a-z0-9\.\-]+$/ ||
				&error(&text('save_etopdoms2', $tld));
			}
		$account->{'doms'} = $in{'doms'};
		}
	if ($in{'ns_def'}) {
		delete($account->{'ns'});
		}
	else {
		my @ns = split(/\s+/, $in{'ns'});
		foreach my $ns (@ns) {
			&to_ipaddress($ns) ||
				&error(&text('save_ens', $ns));
			&check_ipaddress($ns) &&
				&error(&text('save_ensip', $ns));
			}
		@ns || &error(&text('save_enss'));
		$account->{'ns'} = join(" ", @ns);
		}
	my $pfunc = "type_".$reg."_edit_parse";
	my $perr = &$pfunc($account, $in{'registrar'}, \%in);
	&error($perr) if ($perr);

	# Make sure the login actually works
	my $vfunc = "type_".$reg."_validate";
	my $verr = &$vfunc($account);
	&error($verr) if ($verr);

	# Save or create
	&lock_file($account->{'file'} ||
		   "$registrar_accounts_dir/$account->{'id'}");
	&save_registrar_account($account);
	&unlock_file($account->{'file'});
	&redirect("index.cgi");
	}
