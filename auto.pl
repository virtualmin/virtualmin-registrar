#!/usr/local/bin/perl
# Automatically renew domains close to expiry

use strict;
no strict 'refs';
use warnings;
our (%text);

package virtualmin_registrar;
no warnings "once";
$main::no_acl_check++;
use warnings "once";
require './virtualmin-registrar-lib.pl';
&foreign_require("mailboxes");

# Do accounts with renewal
foreach my $account (grep { $_->{'autodays'} ||
			 $_->{'autowarn'} } &list_registrar_accounts()) {
	# Find domains, and get expiry for each
	my @rv;
	my @wrv;
	my $warncount = my $donecount = 0;
	my @doms = &find_account_domains($account);
	my $efunc = "type_".$account->{'registrar'}."_get_expiry";
	my $rfunc = "type_".$account->{'registrar'}."_renew_domain";
	foreach my $d (@doms) {
		&virtual_server::lock_domain($d);
		my $msg;
		my $wmsg;
		my ($ok, $exp) = &$efunc($account, $d);
		my $renewed = 0;
		if (!$ok) {
			# Couldn't get it!
			$msg = &text('auto_eget', $exp);
			}
		elsif ($account->{'autodays'} &&
		       $exp - time() < $account->{'autodays'}*24*60*60) {
			# Time to renew!
			$account->{'rcom_account'} = "xxx";
			my ($ok, $rmsg) = &$rfunc($account, $d,
					      $account->{'autoyears'});
			if ($ok) {
				$msg = &text('auto_done',
					     $account->{'autoyears'});
				$renewed++;
				}
			else {
				$msg = &text('auto_failed', $rmsg);
				}
			$donecount++;
			}
		elsif ($account->{'autowarn'} &&
		       $exp - time() < $account->{'autowarn'}*24*60*60) {
			# Time to send warning
			$wmsg = &text('auto_warnmsg', int(($exp - time()) /
						       (24*60*60)));
			$warncount++;
			}

		# Add to results lists
		if ($msg) {
			push(@rv, [ $account, $d, $msg ]);
			}
		if ($wmsg) {
			push(@wrv, [ $account, $d, $wmsg ]);
			}

		# Clear any cache of registrar expiry time
		if ($renewed) {
			delete($d->{'whois_next'});
			&save_domain($d);
			}
		&virtual_server::unlock_domain($d);
		}

	# Send email to master admin and possibly domain owners if any
	# renewals were done
	if ($donecount) {
		if ($account->{'autoemail'}) {
			&send_auto_email(\@rv, $account->{'autoemail'},
					 $text{'auto_subject'},
					 $text{'auto_results'});
			}
		if ($account->{'autoowner'}) {
			foreach my $e (&unique(map { $_->[1]->{'emailto'} } @rv)) {
				my @rve = grep { $_->[1]->{'emailto'} eq $e } @rv;
				&send_auto_email(\@rve, $e,
						 $text{'auto_subject'},
						 $text{'auto_results'});
				}
			}
		}

	# Send email to if any expiry warnings were generated
	if ($warncount) {
		if ($account->{'autoemail'}) {
			&send_auto_email(\@wrv, $account->{'autoemail'},
					 $text{'auto_wsubject'},
					 $text{'auto_wresults'});
			}
		if ($account->{'autoowner'}) {
			foreach my $e (&unique(map { $_->[1]->{'emailto'}} @wrv)) {
				my @rve = grep { $_->[1]->{'emailto'} eq $e } @wrv;
				&send_auto_email(\@rve, $e,
						 $text{'auto_wsubject'},
						 $text{'auto_wresults'});
				}
			}
		}
	}

# send_auto_email(&messages, email, subject-line, body-heading)
# Send email about some renewals or warnings to an address
sub send_auto_email
{
my ($rv, $email, $subject, $heading) = @_;
my $msg = join("\n", &mailboxes::wrap_lines($heading, 70))."\n\n";
my $fmt = "%-40.40s %-39.39s\n";
$msg .= sprintf $fmt, $text{'auto_rdom'}, $text{'auto_rmsg'};
$msg .= sprintf $fmt, ("-" x 40), ("-" x 39);
foreach my $r (@$rv) {
	$msg .= sprintf $fmt, $r->[1]->{'dom'}, $r->[2];
	}
$msg .= "\n";
&mailboxes::send_text_mail(
	&virtual_server::get_global_from_address(),
	$email,
	undef,
	$subject,
	$msg);
}
