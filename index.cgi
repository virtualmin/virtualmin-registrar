#!/usr/local/bin/perl
# Show a list of accounts, and a menu to add a new one

require 'virtualmin-registrar-lib.pl';
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
		$text{'index_doms'}
		], 100, 0, \@tds);
	foreach $a (@accounts) {
		$dfunc = "type_".$a->{'registrar'}."_desc";
		$desc = &$dfunc($a);
		print &ui_checked_columns_row([
		    "<a href='edit.cgi?id=$a->{'id'}'>".
		     ($a->{'desc'} || $a->{'account'})."</a>",
		    $desc,
		    $a->{'enabled'} ? "<font color=#00aa00>$text{'yes'}</font>"
				    : "<font color=#ff0000>$text{'no'}</font>",
		    $a->{'doms'} ? "<tt>$a->{'doms'}</tt>"
				 : $text{'index_all'}
		    ], \@tds, "d", $a->{'id'});
		}
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
print &ui_form_start("edit.cgi");
print "<b>$text{'index_add'}</b>\n";
print &ui_select("registrar", undef,
	[ map { [ $_->{'name'}, $_->{'desc'} ] } @registrar_types ]);
print &ui_submit($text{'index_addok'});
print &ui_form_end();

# Form to create new registrar account, if any support it
foreach $r (@registrar_types) {
	$cfunc = "type_".$r->{'name'}."_create_inputs";
	push(@create_types, $r) if (defined(&$cfunc));
	}
if (@create_types) {
	print &ui_form_start("create_form.cgi");
	print "<b>$text{'index_create'}</b>\n";
	print &ui_select("registrar", undef,
		[ map { [ $_->{'name'}, $_->{'desc'} ] } @create_types ]);
	print &ui_submit($text{'index_createok'});
	print &ui_form_end();
	}

&ui_print_footer("/", $text{'index'});

