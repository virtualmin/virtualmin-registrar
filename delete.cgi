#!/usr/local/bin/perl
# Enable, disable or delete a bunch of accounts
use strict;
use warnings;
our (%access, %text, %in);

require './virtualmin-registrar-lib.pl';
$access{'registrar'} || &error($text{'edit_ecannot'});
&ReadParse();

# Get the accountS
my %d = map { $_, 1 } split(/\0/, $in{'d'});
my @delaccounts = grep { $d{$_->{'id'}} } &list_registrar_accounts();

if ($in{'disable'}) {
	# Disable selected
	&error_setup($text{'delete_err1'});
	@delaccounts || &error($text{'delete_enone'});
	foreach $a (@delaccounts) {
		$a->{'enabled'} = 0;
		&save_registrar_account($a);
		}
	&webmin_log("disable", undef, scalar(@delaccounts));
	&redirect("");
	}

elsif ($in{'enable'}) {
	# Enable selected
	&error_setup($text{'delete_err2'});
	@delaccounts || &error($text{'delete_enone'});
	foreach my $a (@delaccounts) {
		$a->{'enabled'} = 1;
		&save_registrar_account($a);
		}
	&webmin_log("enable", undef, scalar(@delaccounts));
	&redirect("");
	}

elsif ($in{'delete'}) {
	# Delete selected, if not used and if the user confirms
	&error_setup($text{'delete_err3'});
	@delaccounts || &error($text{'delete_enone'});
	foreach my $a (@delaccounts) {
		my @doms = &find_account_domains($a);
		if (@doms) {
			&error(&text('delete_edoms', "<i>$a->{'desc'}</i>",
			    join(" ", map { "<tt>$_->{'dom'}</tt>" } @doms)));
			}
		}
	if ($in{'confirm'}) {
		# Do it
		foreach my $a (@delaccounts) {
			&delete_registrar_account($a);
			}
		&webmin_log("delete", undef, scalar(@delaccounts));
		&redirect("");
		}
	else {
		# Ask first
		&ui_print_header(undef, $text{'delete_title'}, "");
		print &ui_form_start("delete.cgi", "post");
		foreach my $a (@delaccounts) {
			print &ui_hidden("d", $a->{'id'});
			}
		print &ui_hidden("delete", 1);
		print "<center>",
		      &text('delete_rusure', scalar(@delaccounts)),"<p>\n",
		      &ui_submit($text{'delete_ok'}, 'confirm'),
		      "</center>\n";
		print &ui_form_end();
		&ui_print_footer("", $text{'index_return'});
		}
	}
else {
	&error("No button clicked!");
	}
