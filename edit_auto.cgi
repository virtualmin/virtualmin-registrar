#!/usr/local/bin/perl
# Show a form to setup automatic renewal for some account

require './virtualmin-registrar-lib.pl';
&ReadParse();
&error_setup($text{'auto_err'});
$access{'registrar'} || &error($text{'auto_ecannot'});

# Get the account
($account) = grep { $_->{'id'} eq $in{'id'}} &list_registrar_accounts();
$account || &error($text{'edit_egone'});

&ui_print_header(undef, $text{'auto_title'}, "", "auto");

print &ui_form_start("save_auto.cgi", "post");
print &ui_hidden("id", $in{'id'});
print &ui_hidden_table_start($text{'auto_header1'}, undef, 2, "main", 1,
			     [ "width=30%" ]);

# Account details
print &ui_table_row($text{'auto_account'},
	$account->{'desc'});
$dfunc = "type_".$account->{'registrar'}."_desc";
print &ui_table_row($text{'edit_registrar'},
	&$dfunc($account));

# Renewal policy
print &ui_table_row($text{'auto_days'},
	&ui_radio("days_def", $account->{'autodays'} ? 0 : 1,
	  [ [ 1, $text{'auto_off'} ],
	    [ 0, &text('auto_on',
		       &ui_textbox("days", $account->{'autodays'}, 5)) ] ]));

# How long to renew for
$yfunc = "type_".$account->{'registrar'}."_renew_years";
print &ui_table_row($text{'auto_years'},
	&ui_textbox("years", $account->{'autoyears'} || &$yfunc($account), 5));

# Send email to
print &ui_table_row($text{'auto_email'},
	&ui_opt_textbox("email", $account->{'autoemail'}, 40,
			$text{'auto_none'}, $text{'auto_addr'}));

print &ui_hidden_table_end("main");

print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});
