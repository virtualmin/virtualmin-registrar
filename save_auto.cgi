#!/usr/local/bin/perl
# Save automatic renewal
use strict;
no strict 'refs';
use warnings;
our (%access, %text, %in);
our $auto_cron_cmd;
our $module_name;

require './virtualmin-registrar-lib.pl';
&foreign_require("cron", "cron-lib.pl");
&ReadParse();
&error_setup($text{'auto_err'});
$access{'registrar'} || &error($text{'auto_ecannot'});

# Get the account
my ($account) = grep { $_->{'id'} eq $in{'id'}} &list_registrar_accounts();
$account || &error($text{'edit_egone'});

# Validate inputs
if ($in{'days_def'}) {
	delete($account->{'autodays'});
	}
else {
	$in{'days'} =~ /^[1-9]\d*$/ || &error($text{'auto_edays'});
	$account->{'autodays'} = $in{'days'};
	}
if ($in{'warn_def'}) {
	delete($account->{'autowarn'});
	}
else {
	$in{'warn'} =~ /^[1-9]\d*$/ || &error($text{'auto_ewarn'});
	$account->{'autowarn'} = $in{'warn'};
	}
if ($in{'email_def'}) {
	delete($account->{'autoemail'});
	}
else {
	$in{'email'} =~ /^\S+\@\S+$/ || &error($text{'auto_eemail'});
	$account->{'autoemail'} = $in{'email'};
	}
$in{'years'} =~ /^[1-9]\d*$/ || &error($text{'auto_eyears'});
$account->{'autoyears'} = $in{'years'};
$account->{'autoowner'} = $in{'owner'};

# Save the account, and create the cron job if needed
&save_registrar_account($account);
my ($job) = grep { $_->{'command'} eq $auto_cron_cmd &&
		$_->{'user'} eq 'root' } &cron::list_cron_jobs();
my @anyauto = grep { $_->{'autodays'} || $_->{'autowarn'} }
		&list_registrar_accounts();
if (@anyauto && !$job) {
	# Create the job
	$job = { 'user' => 'root',
		 'command' => $auto_cron_cmd,
		 'active' => 1,
		 'mins' => int(rand()*60),
		 'hours' => 0,
		 'days' => '*',
		 'months' => '*',
		 'weekdays' => '*' };
	&lock_file(&cron::cron_file($job));
	&cron::create_cron_job($job);
	&unlock_file(&cron::cron_file($job));
	}
elsif (!@anyauto && $job) {
	# Delete the job
	&lock_file(&cron::cron_file($job));
	&cron::delete_cron_job($job);
	&unlock_file(&cron::cron_file($job));
	}
&cron::create_wrapper($auto_cron_cmd, $module_name, "auto.pl");

&redirect("");
