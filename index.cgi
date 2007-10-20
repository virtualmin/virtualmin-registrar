#!/usr/local/bin/perl
# Show a list of accounts, and a menu to add a new one

require 'virtualmin-registrar-lib.pl';
if (!$access{'registrar'}) {
	# Non-admin users who access this page should be shown a list
	# of their registered domains instead
	&redirect("list.cgi");
	exit;
	}
&ui_print_header(undef, $text{'index_title'}, "", "intro", 0, 1);

# Table of existing accounts
@accounts = &list_registrar_accounts();
if (@accounts) {
	print &ui_form_start("delete.cgi", "post");
	@links = ( &select_all_link("d"), &select_invert_link("d") );
	@tds = ( "width=5" );
	print &ui_links_row(\@links);
	print &ui_columns_start([
		"",
		$text{'index_desc'},
		$text{'index_registrar'},
		$text{'index_enabled'},
		$text{'index_acts'}
		], 100, 0, \@tds);
	foreach $a (@accounts) {
		$dfunc = "type_".$a->{'registrar'}."_desc";
		$desc = &$dfunc($a);
		@links = ( );
		$msg = &text('index_msg', "<i>$a->{'desc'}</i>");
		$nonemsg = &text('index_nonemsg', "<i>$a->{'desc'}</i>");
		push(@links, "<a href='../virtual-server/search.cgi?".
			     "field=registrar_account&what=$a->{'id'}&".
			     "msg=".&urlize($msg)."&".
			     "nonemsg=".&urlize($nonemsg)."'>".
			     "$text{'index_actdoms'}</a>");
		push(@links, "<a href='edit_auto.cgi?id=$a->{'id'}'>".
			     "$text{'index_actauto'}</a>");
		if ($a->{'autodays'}) {
			$links[$#links] = "<i>".$links[$#links]."</i>";
			}
		print &ui_checked_columns_row([
		    "<a href='edit.cgi?id=$a->{'id'}'>".
		     ($a->{'desc'} || $a->{'account'})."</a>",
		    $desc,
		    $a->{'enabled'} ? "<font color=#00aa00>$text{'yes'}</font>"
				    : "<font color=#ff0000>$text{'no'}</font>",
		    &ui_links_row(\@links),
		    ], \@tds, "d", $a->{'id'});
		}
	print &ui_columns_end();
	print &ui_links_row(\@links);
	print &ui_form_end([
		[ "disable", $text{'index_disable'} ],
		[ "enable", $text{'index_enable'} ],
		undef,
		[ "delete", $text{'index_delete'} ],
		]);
	}
else {
	print "<b>$text{'index_none'}</b><p>\n";
	}

# Form to add existing registrar account
print "<table>\n";
print &ui_form_start("edit.cgi");
print "<tr> <td><b>$text{'index_add'}</b></td>\n";
print "<td>".&ui_select("registrar", undef,
	[ map { [ $_->{'name'}, $_->{'desc'} ] } @registrar_types ])."</td>\n";
print "<td>".&ui_submit($text{'index_addok'})."</td> </tr>\n";
print &ui_form_end();

# Form to create new registrar account, if any support it
foreach $r (@registrar_types) {
	$cfunc = "type_".$r->{'name'}."_create_inputs";
	push(@create_types, $r) if (defined(&$cfunc));
	}
if (@create_types) {
	print &ui_form_start("create_form.cgi");
	print "<tr> <td><b>$text{'index_create'}</b></td>\n";
	print "<td>".&ui_select("registrar", undef,
	    [ map { [ $_->{'name'}, $_->{'desc'} ] } @create_types ])."</td>\n";
	print "<td>".&ui_submit($text{'index_createok'})."</td> </tr>\n";
	print &ui_form_end();
	}

print "</table>\n";

&ui_print_footer("/", $text{'index'});

