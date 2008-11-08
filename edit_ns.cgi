#!/usr/local/bin/perl
# Show a form for editing nameservers for a domain

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'ns_err'});

# Get the Virtualmin domain
&can_domain($in{'dom'}) || &error($text{'ns_ecannot'});
$d = &virtual_server::get_domain_by("dom", $in{'dom'});
$d || &error(&text('contact_edom', $in{'dom'}));
&can_nameservers($d) || &error($text{'ns_ecannot'});
($account) = grep { $_->{'id'} eq $d->{'registrar_account'} }
		  &list_registrar_accounts();
$account || &error(&text('contact_eaccount', $in{'dom'}));

# Get nameserver info from registrar
$cfunc = "type_".$account->{'registrar'}."_get_nameservers";
$nss = &$cfunc($account, $d);
ref($nss) || &error($nss);

# Get nameservers Virtualmin expects, and in BIND zone
$enss = &get_domain_nameservers($account, $d);
$znss = &get_domain_nameservers(undef, $d);
$same_nss = join(" ", sort { $a cmp $b } map { lc($_) } @$nss) eq
	    join(" ", sort { $a cmp $b } map { lc($_) } @$enss) ? 1 : 0;
$sync_nss = join(" ", sort { $a cmp $b } map { lc($_) } @$nss) eq
	    join(" ", sort { $a cmp $b } map { lc($_) } @$znss) ? 1 : 0;

&ui_print_header(&virtual_server::domain_in($d), $text{'ns_title'}, "", "ns");

# Form start
print &ui_form_start("save_ns.cgi", "post");
print &ui_hidden("dom", $in{'dom'});
print &ui_table_start($text{'ns_header'}, undef, 2);

# Show nameservers with registrar
print &ui_table_row($text{'ns_ns'},
	&ui_radio_table("same", $same_nss, 
		[ [ 1, $text{'ns_same'},
		       join(" , ", map { "<tt>$_</tt>" } @$enss) ],
		  [ 2, $text{'ns_diff'},
		       &ui_textarea("ns", join("\n", @$nss), 4, 30) ] ]));

# Show nameservers in BIND
print &ui_table_row($text{'ns_bind'},
	join(" , ", map { "<tt>$_</tt>" } @$znss)."<br>\n".
	&ui_checkbox("sync", 1, $text{'ns_sync'}, $sync_nss));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer(&virtual_server::domain_footer_link($d));

