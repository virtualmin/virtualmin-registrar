#!/usr/local/bin/perl
# Show a list of registered domains accessible to the current user

require 'virtualmin-registrar-lib.pl';
&ui_print_header(undef, $text{'list_title'}, "");

# Find the domains
@doms = grep { $_->{$module_name} &&
	       &virtual_server::can_edit_domain($_) }
	     &virtual_server::list_domains();

# Show each domain, with registration info
@accounts = &list_registrar_accounts();
@table = ( );
foreach $d (@doms) {
	$url = &virtual_server::can_config_domain($d) ?
		"../virtual-server/edit_domain.cgi?id=$d->{'id'}" :
		"../virtual-server/view_domain.cgi?id=$d->{'id'}";
	($account) = grep { $_->{'id'} eq $d->{'registrar_account'} }
			  @accounts;
	$rfunc = "type_".$account->{'registrar'}."_desc"
		if ($account);
	$dname = &virtual_server::show_domain_name($d);
	push(@table, [
		"<a href='$url'>$dname</a>",
		$account ? ( &$rfunc($account),
			     $account->{'desc'} )
			 : ( "None", "None" ),
		$d->{'registrar_id'}
		]);
	}
print &ui_columns_table(
	[ $text{'list_dom'}, $text{'list_registrar'},
	  $text{'list_account'}, $text{'list_id'}, ],
	100, \@table, undef, 0, undef, $text{'list_none'});

&ui_print_footer("/", $text{'index'});
