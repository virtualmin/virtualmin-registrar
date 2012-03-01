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
@schema = &get_contact_schema($account);
foreach $con (@$contacts) {
	my @row = ( "<a href='edit_onecontact.cgi?id=$in{'id'}&".
		    "cid=$con->{'id'}'>".&html_escape($con->{'id'})."</a>" );
	foreach $s (@schema[1..5]) {
		$v = $con->{$s->{'name'}};
		if ($s->{'choices'}) {
			($c) = grep { $_->[0] eq $v } @{$s->{'choices'}};
			$v = $c->[1] if ($c);
			}
		push(@row, $v);
		}
	push(@table, \@row);
	}

print &ui_columns_table(
	[ $text{'contacts_id'}, 
	  map { $text{'contact_'.$_->{'name'}} } @schema[1..5],
	],
	100, \@table, undef, 0, undef,
	$text{'contacts_none'});

# Create links for adding contacts of different types
@links = ( );
$cfunc = "type_".$account->{'registrar'}."_get_contact_classes";
foreach my $c (&$cfunc($account)) {
	push(@links, "<a href='edit_onecontact.cgi?new=1&id=$in{'id'}".
		     "&cls=$c->{'id'}'>".&text('contacts_add', $c->{'desc'}).
		     "</a>");
	}
print &ui_links_row(\@links);

&ui_print_footer("", $text{'index_return'});
