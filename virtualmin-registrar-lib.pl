# Common functions for domain registration
# XXX don't allow deletion of accounts that have domains
# XXX accounts have enabled flag to control use

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
&foreign_require("virtual-server", "virtual-server-lib.pl");
$registrar_accounts_dir = "$module_config_directory/accounts";

# Bring in all register-type specific libraries
@registrar_types = (
	{ 'name' => 'rcom',
	  'desc' => $text{'type_rcom'},
	},
    );
foreach my $t (@registrar_types) {
	do $t.'-type-lib.pl';
	}

# list_registrar_accounts
# Returns a list of registrar accounts that have been setup for use in
# this module.
sub list_registrar_accounts
{
local @rv;
opendir(DIR, $registrar_accounts_dir);
foreach my $f (readdir(DIR)) {
	next if ($f eq "." || $f eq "..");
	local %account;
	&read_file("$registrar_accounts_dir/$f", \%account);
	$account{'id'} = $f;
	push(@rv, \%account);
	}
closedir(DIR);
return @rv;
}

# save_registrar_account(&account)
# Create or update a registrar account
sub save_registrar_account
{
local ($account) = @_;
$account->{'id'} ||= time().$$;
&write_file("$registrar_accounts_dir/$account->{'id'}", $account);
}

# delete_registrar_account(&account)
# Mark an existing registrar account as deleted
sub delete_registrar_account
{
local ($account) = @_;
&unlink_file("$registrar_accounts_dir/$account->{'id'}");
}

# find_registrar_account(domain)
# Returns the best registrar account for some domain
sub find_registrar_account
{
# XXX
}

# find_account_domains(&account)
# Returns a list of Virtualmin domains using some account
sub find_account_domains
{
local ($account) = @_;
local @rv;
foreach my $d (&virtual_server::list_domains()) {
	push(@rv, $d) if ($d->{$module_name} &&
			  $d->{'registrar_account'} eq $account->{'id'});
	}
return @rv;
}

1;

