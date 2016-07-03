#!/usr/local/bin/perl
# Show a list of registered domains accessible to the current user
use strict;
use warnings;
our (%text, %in);
our $module_name;

require 'virtualmin-registrar-lib.pl';
&ReadParse();

# Find the domains
my @doms = grep { $_->{$module_name} &&
	       &virtual_server::can_edit_domain($_) }
	     &virtual_server::list_domains();

# Get relevant accounts
my @accounts = &list_registrar_accounts();
if ($in{'id'}) {
	# Just one account
	@accounts = grep { $_->{'id'} eq $in{'id'} } @accounts;
	}

&ui_print_header($in{'id'} ? $accounts[0]->{'desc'} : undef,
		 $text{'list_title'}, "");

# Show each domain, with registration info
my @table;
foreach my $d (@doms) {
	my $url = &virtual_server::can_config_domain($d) ?
		"../virtual-server/edit_domain.cgi?dom=$d->{'id'}" :
		"../virtual-server/view_domain.cgi?dom=$d->{'id'}";
	my ($account) = grep { $_->{'id'} eq $d->{'registrar_account'} }
			  @accounts;
	next if (!$account);
	my $rfunc = "type_".$account->{'registrar'}."_desc";
	my $dname = &virtual_server::show_domain_name($d);

	# Get expiry date, if possible
	my $efunc = "type_".$account->{'registrar'}."_get_expiry";
	my $expiry = undef;
	if (defined(&$efunc)) {
		(my $ok, $expiry) = &$efunc($account, $d);
		$expiry = undef if (!$ok);
		}
	push(@table, [
		"<a href='$url'>$dname</a>",
		$account ? ( &$rfunc($account),
			     $account->{'desc'} )
			 : ( "None", "None" ),
		$d->{'registrar_id'},
		$expiry ? &make_date($expiry, 1) : undef,
		]);
	}
print &ui_columns_table(
	[ $text{'list_dom'}, $text{'list_registrar'},
	  $text{'list_account'}, $text{'list_id'},
	  $text{'list_expiry'}, ],
	100, \@table, undef, 0, undef,
	$in{'id'} ? $text{'list_none2'} : $text{'list_none'});

&ui_print_footer("/", $text{'index'});
