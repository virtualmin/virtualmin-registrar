#!/usr/local/bin/perl
# Show a list of accounts, and a menu to add a new one

use strict;
no strict 'refs';
use warnings;
our (%access, %text);
our @registrar_types;

require 'virtualmin-registrar-lib.pl';
if (!$access{'registrar'}) {
	# Non-admin users who access this page should be shown a list
	# of their registered domains instead
	&redirect("list.cgi");
	exit;
	}
&ui_print_header(undef, $text{'index_title'}, "", "intro", 0, 1);

# Build table of existing accounts
my @accounts = &list_registrar_accounts();
my @table;
foreach my $a (sort { $a->{'desc'} cmp $b->{'desc'} } @accounts) {
	my $dfunc = "type_".$a->{'registrar'}."_desc";
	my $desc = &$dfunc($a);
	my @links;
	my $msg = &text('index_msg', "<i>$a->{'desc'}</i>");
	my $nonemsg = &text('index_nonemsg', "<i>$a->{'desc'}</i>");
	push(@links, "<a href='../virtual-server/search.cgi?".
		     "field=registrar_account&what=$a->{'id'}&".
		     "msg=".&urlize($msg)."&".
		     "nonemsg=".&urlize($nonemsg)."'>".
		     "$text{'index_actvirts'}</a>");
	push(@links, "<a href='list.cgi?id=$a->{'id'}'>".
		     "$text{'index_actdoms'}</a>");
	push(@links, "<a href='edit_auto.cgi?id=$a->{'id'}'>".
		     "$text{'index_actauto'}</a>");
	my $cfunc = "type_".$a->{'registrar'}."_list_contacts";
	if (defined(&$cfunc)) {
		push(@links, "<a href='list_contacts.cgi?id=$a->{'id'}'>".
			     "$text{'index_actcontacts'}</a>");
		}
	if ($a->{'autodays'} || $a->{'autowarn'}) {
		$links[$#links] = "<i>".$links[$#links]."</i>";
		}
	push(@table, [
	    { 'type' => 'checkbox', 'name' => 'd', 'value' => $a->{'id'} },
	    "<a href='edit.cgi?id=$a->{'id'}'>".
	     ($a->{'desc'} || $a->{'account'})."</a>",
	    $desc,
	    $a->{'enabled'} ? "<font color=#00aa00>$text{'yes'}</font>"
			    : "<font color=#ff0000>$text{'no'}</font>",
	    &ui_links_row(\@links),
	    ]);
	}

# Print table of accounts
print &ui_form_columns_table(
	"delete.cgi",
	[ [ "disable", $text{'index_disable'} ],
          [ "enable", $text{'index_enable'} ],
          undef,
          [ "delete", $text{'index_delete'} ], ],
	1,
	[ [ "list.cgi", $text{'index_listall'} ] ],
	undef,
	[ "", $text{'index_desc'}, $text{'index_registrar'},
	  $text{'index_enabled'}, $text{'index_acts'} ],
	100,
	\@table,
	undef,
	0,
	undef,
	$text{'index_none'});

# Form to add existing registrar account
print &ui_hr();

print &ui_form_start("edit.cgi");
print "<b>$text{'index_add'}</b>\n";
print &ui_select("registrar", undef,
	[ map { [ $_->{'name'}, $_->{'desc'} ] }
	      grep { !$_->{'disabled'} } @registrar_types ]),"\n";
print &ui_submit($text{'index_addok'});
print &ui_form_end();

&ui_print_footer("/", $text{'index'});
