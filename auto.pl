#!/usr/local/bin/perl
# Automatically renew domains close to expiry

package virtualmin_registrar;
$main::no_acl_check++;
require './virtualmin-registrar-lib.pl';

# Do accounts with renewal
foreach $account (grep { $_->{'autodays'} } &list_registrar_accounts()) {
	# Find domains, and get expiry for each
	@rv = ( );
	$donecount = 0;
	@doms = &find_account_domains($account);
	$efunc = "type_".$account->{'registrar'}."_get_expiry";
	$rfunc = "type_".$account->{'registrar'}."_renew_domain";
	foreach $d (@doms) {
		$msg = undef;
		($ok, $exp) = &$efunc($account, $d);
		if (!$ok) {
			# Couldn't get it!
			$msg = &text('auto_eget', $exp);
			}
		elsif ($exp - time() < $account->{'autodays'}*24*60*60) {
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

		if ($msg) {
			# Add to results list
			push(@rv, [ $account, $d, $msg ]);
			}
		}

	# Send email if anything was done
	if ($donecount && $account->{'autoemail'}) {
		&foreign_require("mailboxes", "mailboxes-lib.pl");
		$msg = join("\n", &mailboxes::wrap_lines(
					$text{'auto_results'}, 70))."\n\n";
		$fmt = "%-40.40s %-39.39s\n";
		$msg .= sprintf $fmt, $text{'auto_rdom'}, $text{'auto_rmsg'};
		$msg .= sprintf $fmt, ("-" x 40), ("-" x 39);
		foreach $r (@rv) {
			$msg .= sprintf $fmt, $r->[1]->{'dom'}, $r->[2];
			}
		$msg .= "\n";
		&mailboxes::send_text_mail(
			$virtual_server::config{'from_addr'} ||
				&mailboxes::get_from_address(),
			$account->{'autoemail'},
			undef,
			$text{'auto_subject'},
			$msg);
		}
	}

