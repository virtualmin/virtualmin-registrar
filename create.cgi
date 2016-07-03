#!/usr/local/bin/perl
# Create a new registrar account
use strict;
use warnings;
our (%access, %text, %in);

require './virtualmin-registrar-lib.pl';
&error_setup($text{'create_err'});
$access{'registrar'} || &error($text{'create_ecannot'});
&ReadParse();
my $reg = $in{'registrar'};

# Validate and store inputs
my $account = { 'id' => time().$$,
	     'registrar' => $reg,
	     'enabled' => 1 };
$in{'desc'} =~ /\S/ || &error($text{'save_edesc'});
$account->{'desc'} = $in{'desc'};
my $pfunc = "type_".$reg."_create_parse";
my $err = &$pfunc($account, \%in);
&error($err) if ($err);

# Do the creation
&ui_print_unbuffered_header(undef, $text{'create_title'}, "", "create");

my $dfunc = "type_".$reg."_desc";
print &text('create_doing', &$dfunc()),"<br>\n";
my $cfunc = "type_".$reg."_create_account";
my ($ok, $msg, $warn, $extra) = &$cfunc($account);
if ($ok) {
	if ($warn) {
		print &text('create_warn', $msg, $warn),"<p>\n";
		}
	else {
		print &text('create_done', $msg),"<p>\n";
		}
	&save_registrar_account($account);
	}
else {
	print &text('create_failed', $msg),"<p>\n";
	}
if ($extra) {
	print $extra,"<p>\n";
	}

&ui_print_footer("", $text{'index_return'});
