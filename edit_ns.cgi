#!/usr/local/bin/perl
# Show a form for editing nameservers for a domain
use strict;
use warnings;
our (%text, %in);

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'ns_err'});

# Get the Virtualmin domain
&can_domain($in{'dom'}) || &error($text{'ns_ecannot'});
my $d = &virtual_server::get_domain_by("dom", $in{'dom'});
$d || &error(&text('contact_edom', $in{'dom'}));
&can_nameservers($d) || &error($text{'ns_ecannot'});
my ($account) = grep { $_->{'id'} eq $d->{'registrar_account'} }
		  &list_registrar_accounts();
$account || &error(&text('contact_eaccount', $in{'dom'}));

# Get nameserver info from registrar
my $cfunc = "type_".$account->{'registrar'}."_get_nameservers";
my $nss = &$cfunc($account, $d);
ref($nss) || &error($nss);

# Get nameservers Virtualmin expects, and in BIND zone
my $enss = &get_domain_nameservers($account, $d);
my $znss = &get_domain_nameservers(undef, $d);
my $same_nss = &ns_list_to_string(@$nss) eq &ns_list_to_string(@$enss) ? 1 : 0;
my $sync_nss = &ns_list_to_string(@$nss) eq &ns_list_to_string(@$znss) ? 1 : 0;

&ui_print_header(&virtual_server::domain_in($d), $text{'ns_title'}, "", "ns");

# Form start
print &ui_form_start("save_ns.cgi", "post");
print &ui_hidden("dom", $in{'dom'});
print &ui_table_start($text{'ns_header'}, undef, 2);

# Show registrar account
print &ui_table_row($text{'ns_account'},
		    $account->{'desc'});

# Show nameservers with registrar
print &ui_table_row($text{'ns_ns'},
	&ui_radio_table("same", $same_nss,
		[ [ 1, $text{'ns_same'},
		       join(" , ", map { "<tt>$_</tt>" } @$enss) ],
		  [ 0, $text{'ns_diff'},
		       &ui_textarea("ns", join("\n", @$nss), 4, 30) ] ]));

# Show nameservers in BIND
print &ui_table_row($text{'ns_bind'},
	join(" , ", map { "<tt>$_</tt>" } @$znss)."<br>\n".
	&ui_checkbox("sync", 1, $text{'ns_sync'}, $sync_nss));

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer(&virtual_server::domain_footer_link($d));

sub ns_list_to_string
{
return join(" ", sort { $a cmp $b } &unique(map { lc($_) } @_));
}
