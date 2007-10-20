#!/usr/local/bin/perl
# Automatically renew domains close to expiry

package virtualmin_registrar;
$main::no_acl_check++;
require './virtualmin-registrar-lib.pl';

# Do accounts with renewal
foreach $account (grep { $_->{'autodays'} } &list_registrar_accounts()) {
	# Find domains, and get expiry for each
	@rv = ( );
	@doms = &find_account_domains($account);
	$efunc = "type_".$account->{'registrar'}."_get_expiry";
	$rfunc = "type_".$account->{'registrar'}."_renew_domain";
	foreach $d (@doms) {
		$msg = undef;
		($ok, $exp) = &$efunc($account, $d);
		print STDERR "account=$account->{'desc'} dom=$d->{'dom'} ok=$ok exp=$exp\n";
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
			}
		print STDERR "msg=$msg\n";

		if ($msg) {
			# Add to results list
			push(@rv, [ $account, $d, $msg ]);
			}
		}

	# Send email if anything was done
	print STDERR "rv=",scalar(@rv)," email=$account->{'autoemail'}\n";
	if (@rv && $account->{'autoemail'}) {
		&foreign_require("mailboxes", "mailboxes-lib.pl");
		$msg = join("\n", &mailboxes::wrap_lines(
					$text{'auto_results'}, 70))."\n\n";
		$fmt = "%-20.20s %-30.30s %-28.28s\n";
		$msg .= sprintf $fmt, $text{'auto_raccount'}, $text{'auto_rdom'},
				      $text{'auto_rmsg'};
		$msg .= sprintf $fmt, ("-" x 20), ("-" x 30), ("-" x 28);
		foreach $r (@rv) {
			$msg .= sprintf $fmt, $r->[0]->{'desc'},
					      $r->[1]->{'dom'}, $r->[2];
			}
		$msg .= "\n";
		&mailboxes::send_text_mail(
			$virtual_server::config{'from_addr'} ||
				&mailboxes::get_from_address(),
			$account->{'autoemail'},
			undef,
			$text{'auto_subject'},
			$msg);
		print STDERR "sent $msg\n";
		}
	}

