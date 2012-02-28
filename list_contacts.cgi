#!/usr/local/bin/perl
# Show a list of contacts associated with some account

require 'virtualmin-registrar-lib.pl';
&ReadParse();

# Get the account
@accounts = &list_registrar_accounts();
($account) = grep { $_->{'id'} eq $in{'id'} } @accounts;
$account || &error($text{'contacts_eaccount'});

&ui_print_header($account->{'desc'}, $text{'contacts_title'}, "");

# Get the contacts
$cfunc = "type_".$account->{'registrar'}."_list_contacts";
($ok, $contacts) = &$cfunc($account);
$ok || &error(&text('contacts_elist', $contacts));

# Show each contact, with links to edit
@tables = ( );
foreach $con (@$contacts) {
	push(@table, [
		"<a href='edit_onecontact.cgi?id=$in{'id'}&cid=$con->{'id'}'>".
		  &html_escape($con->{'id'})."</a>",
		$con->{'name'},
		]);
	}

print &ui_columns_table(
	[ $text{'contacts_id'}, $text{'contacts_name'},
	],
	100, \@table, undef, 0, undef,
	$text{'contacts_none'});
print &ui_links_row([ "<a href='edit_onecontact.cgi?new=1&id=$in{'id'}'>".
		      "$text{'contacts_add'}</a>" ]);

&ui_print_footer("/", $text{'index'});
