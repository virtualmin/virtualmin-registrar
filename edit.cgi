#!/usr/local/bin/perl
# Show a form for adding or editing an existing registrar account

require './virtualmin-registrar-lib.pl';
$access{'registrar'} || &error($text{'edit_ecannot'});
&ReadParse();
&ui_print_header(undef, $in{'registrar'} ? $text{'edit_title1'}
					 : $text{'edit_title2'}, "",
		        $in{'registrar'} ? "add" : "edit");
if ($in{'registrar'}) {
	$reg = $in{'registrar'};
	}
else {
	($account) = grep { $_->{'id'} eq $in{'id'}} &list_registrar_accounts();
	$account || &error($text{'edit_egone'});
	$reg = $account->{'registrar'};
	}

print &ui_form_start("save.cgi", "post");
print &ui_hidden("registrar", $in{'registrar'});
print &ui_hidden("id", $in{'id'});
print &ui_hidden_table_start($text{'edit_header'}, undef, 2, "main", 1);

# Registrar type
$dfunc = "type_".$reg."_desc";
print &ui_table_row($text{'edit_registrar'}, &$dfunc($account));

# Description
print &ui_table_row($text{'edit_desc'},
	&ui_textbox("desc", $account->{'desc'}, 60));

# Initially enabled
print &ui_table_row($text{'edit_enabled'},
	&ui_yesno_radio("enabled",
			$in{'registrar'} ? 1 : $account->{'enabled'}));

# Nameservers
@defns = &get_default_nameservers();
print &ui_table_row($text{'edit_ns'},
	&ui_radio("ns_def", $account->{'ns'} ? 0 : 1,
	   [ [ 1, &text('edit_ns1',
			join(" , ", map { "<tt>$_</tt>" } @defns))."<br>" ],
	     [ 0, $text{'edit_ns0'}." ".
			&ui_textbox("ns", $account->{'ns'}, 50) ] ]));

# Registrar-specific fields
$efunc = "type_".$reg."_edit_inputs";
print &$efunc($account, $in{'registrar'} ? 1 : 0);

if (!$in{'registrar'}) {
	# Used for domains
	@doms = &find_account_domains($account);
	@links = ( );
	foreach my $d (@doms) {
		if (&virtual_server::can_config_domain($d)) {
			push(@links, "<a href='../virtual-server/edit_domain.cgi?dom=$d->{'id'}'>$d->{'dom'}</a>");
			}
		else {
			push(@links, $d->{'dom'});
			}
		}
	print &ui_table_row($text{'edit_vdoms'},
		@links ? &ui_links_row(\@links) : $text{'edit_none'});
	}

print &ui_hidden_table_end("main");

# Supported domains section
print &ui_hidden_table_start($text{'edit_header2'}, undef, 2, "tlds", 0);

# Registrar's top-level domains
$tfunc = "type_".$reg."_domains";
if (defined(&$tfunc)) {
	@tlds = &$tfunc();
	print &ui_table_row($text{'edit_rdoms'},
		&ui_grid_table([ map { "<tt>$_</tt>" } @tlds ], 8, 100));
	}

# Your top-level domains
print &ui_table_row($text{'edit_doms'},
	&ui_opt_textbox("doms", $account->{'doms'}, 50, $text{'edit_all'},
			$text{'edit_suffixes'}));

print &ui_hidden_table_end("tlds");


if ($in{'registrar'}) {
	print &ui_form_end([ [ undef, $text{'create'} ] ]);
	}
else {
	print &ui_form_end([ [ undef, $text{'save'} ],
			     [ "delete", $text{'edit_delete'} ] ]);
	}

&ui_print_footer("", $text{'index_return'});

