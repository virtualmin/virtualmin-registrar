#!/usr/local/bin/perl
# Show a list of registered domains accessible to the current user

require 'virtualmin-registrar-lib.pl';
&ui_print_header(undef, $text{'list_title'}, "");

# Find the domains
@doms = grep { $_->{$module_name} &&
	       &virtual_server::can_edit_domain($_) }
	     &virtual_server::list_domains();
if (@doms) {
	# Show each domain, with registration info
	print &ui_columns_start([
		$text{'list_dom'},
		$text{'list_registrar'},
		$text{'list_account'},
		$text{'list_id'},
		]);
	@accounts = &list_registrar_accounts();
	foreach $d (@doms) {
		$url = &virtual_server::can_config_domain($d) ?
			"../virtual-server/edit_domain.cgi?id=$d->{'id'}" :
			"../virtual-server/view_domain.cgi?id=$d->{'id'}";
		($account) = grep { $_->{'id'} eq $d->{'registrar_account'} }
				  @accounts;
		$rfunc = "type_".$account->{'registrar'}."_desc"
			if ($account);
		print &ui_columns_row([
			"<a href='$url'>$d->{'dom'}</a>",
			$account ? ( &$rfunc($account),
				     $account->{'desc'} )
				 : ( "None", "None" ),
			$d->{'registrar_id'}
			]);
		}
	print &ui_columns_end();
	}
else {
	print "<b>$text{'list_none'}</b><p>\n";
	}

&ui_print_footer("/", $text{'index'});
