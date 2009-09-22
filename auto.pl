#!/usr/local/bin/perl
# Automatically renew domains close to expiry

package virtualmin_registrar;
$main::no_acl_check++;
require './virtualmin-registrar-lib.pl';
&foreign_require("mailboxes", "mailboxes-lib.pl");

# Do accounts with renewal
foreach $account (grep { $_->{'autodays'} ||
			 $_->{'autowarn'} } &list_registrar_accounts()) {
	# Find domains, and get expiry for each
	@rv = ( );
	@wrv = ( );
	$warncount = $donecount = 0;
	@doms = &find_account_domains($account);
	$efunc = "type_".$account->{'registrar'}."_get_expiry";
	$rfunc = "type_".$account->{'registrar'}."_renew_domain";
	foreach $d (@doms) {
		$msg = undef;
		$wmsg = undef;
		($ok, $exp) = &$efunc($account, $d);
		if (!$ok) {
			# Couldn't get it!
			$msg = &text('auto_eget', $exp);
			}
		elsif ($account->{'autodays'} &&
		       $exp - time() < $account->{'autodays'}*24*60*60) {
			# Time to renew!
			$account->{'rcom_account'} = "xxx";
			($ok, $rmsg) = &$rfunc($account, $d,
					      $account->{'autoyears'});
			if ($ok) {
				$msg = &text('auto_done',
					     $account->{'autoyears'});
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
			foreach $e (&unique(map { $_->[1]->{'emailto'} } @rv)) {
				@rve = grep { $_->[1]->{'emailto'} eq $e } @rv;
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
			foreach $e (&unique(map { $_->[1]->{'emailto'}} @wrv)) {
				@rve = grep { $_->[1]->{'emailto'} eq $e } @wrv;
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
local ($rv, $email, $subject, $heading) = @_;
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
