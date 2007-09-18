#!/usr/local/bin/perl
# Create, update or delete a registrar account

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'save_err'});

# Get the account object and registrar type
if ($in{'registrar'}) {
	$reg = $in{'registrar'};
	$account = { 'id' => time().$$,
		     'registrar' => $reg };
	}
else {
	($account) = grep { $_->{'id'} eq $in{'id'}} &list_registrar_accounts();
	$account || &error($text{'edit_egone'});
	$reg = $account->{'registrar'};
	}

if ($in{'delete'}) {
	# Check if in use by any Virtualmin domains - if so, we can't delete
	&error_setup($text{'save_err2'});
	@doms = &find_account_domains($account);
	if (@doms) {
		&error(&text('save_edoms',
			join(" ", map { "<tt>$_->{'dom'}</tt>" } @doms)));
		}

	if ($in{'confirm'}) {
		# Just delete it
		&lock_file($account->{'file'});
		&delete_registrar_account($account);
		&unlock_file($account->{'file'});
		}
	else {
		# Ask first
		&ui_print_header(undef, $text{'save_dtitle'}, "");
		print &ui_form_start("save.cgi", "post");
		print &ui_hidden("id", $in{'id'});
		print &ui_hidden("delete", 1);
		print "<center>",
		     &text('save_drusure', "<i>$account->{'desc'}</i>"),"<p>\n",
		     &ui_submit($text{'save_dok'}, 'confirm'),
		     "</center>\n";
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
		foreach $tld (split(/\s+/, $in{'doms'})) {
			$tld =~ /^\.[a-z0-9\.\-]+$/ ||
				&error(&text('save_etopdoms2', $tld));
			}
		$account->{'doms'} = $in{'doms'};
		}
	$pfunc = "type_".$reg."_edit_parse";
	$perr = &$pfunc($account, $in{'registrar'}, \%in);
	&error($perr) if ($perr);

	# Make sure the login actually works
	$vfunc = "type_".$reg."_validate";
	$verr = &$vfunc($account);
	&error($verr) if ($verr);

	# Save or create
	&lock_file($account->{'file'} ||
		   "$registrar_accounts_dir/$account->{'id'}");
	&save_registrar_account($account);
	&unlock_file($account->{'file'});
	}
&redirect("index.cgi");

