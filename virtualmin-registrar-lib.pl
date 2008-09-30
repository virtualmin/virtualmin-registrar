# Common functions for domain registration
# XXX - Show and allow editing of nameservers for a domain
# XXX - Gandi contact management

do '../web-lib.pl';
&init_config();
do '../ui-lib.pl';
&foreign_require("virtual-server", "virtual-server-lib.pl");
$registrar_accounts_dir = "$module_config_directory/accounts";
%access = &get_module_acl();
$auto_cron_cmd = "$module_config_directory/auto.pl";
($input_name = $module_name) =~ s/[^A-Za-z0-9]/_/g;

# Bring in all register-type specific libraries
@registrar_types = (
	{ 'name' => 'rcom',
	  'desc' => $text{'type_rcom'} },
	{ 'name' => 'gandi',
	  'desc' => $text{'type_gandi'} },
	{ 'name' => 'distribute',
	  'desc' => $text{'type_distribute'} },
    );
foreach my $t (@registrar_types) {
	do $t->{'name'}.'-type-lib.pl';
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
	$account{'file'} = "$registrar_accounts_dir/$f";
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
if (!-d $registrar_accounts_dir) {
	&make_dir($registrar_accounts_dir, 0700);
	}
$account->{'id'} ||= time().$$;
$account->{'file'} = "$registrar_accounts_dir/$account->{'id'}";
&write_file($account->{'file'}, $account);
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
local ($dname) = @_;
foreach my $a (grep { $_->{'enabled'} } &list_registrar_accounts()) {
	# Does the registrar support this domain?
	local $tfunc = "type_".$a->{'registrar'}."_domains";
	if (defined(&$tfunc)) {
		local @doms = &$tfunc($account);
		if (@doms) {
			next if (!&in_tld_list($dname, \@doms));
			}
		}
	# Does the account want it?
	local @doms = split(/\s+/, $a->{'doms'});
	if (@doms) {
		next if (!&in_tld_list($dname, \@doms));
		}
	return $a;
	}
return undef;
}

# in_tld_list(domain, &suffixes)
# Checks if a domain ends with any of the given suffixes, like .com and .org.au
sub in_tld_list
{
local ($dname, $doms) = @_;
foreach my $d (@$doms) {
	if ($dname =~ /\Q$d\E$/i) {
		return 1;
		}
	}
return 0;
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

# get_contact_schema(&account, &domain, type)
# Returns a list of fields for domain contacts
sub get_contact_schema
{
local @rv = (
	      { 'name' => 'organizationname',
		'size' => 60,
		'opt' => 0 },
	      { 'name' => 'firstname',
		'size' => 40,
		'opt' => 0 },
	      { 'name' => 'lastname',
		'size' => 40,
		'opt' => 0 },
	      { 'name' => 'jobtitle',
		'size' => 60,
		'opt' => 1 },
	      { 'name' => 'address1',
		'size' => 60,
		'opt' => 0 },
	      { 'name' => 'address2',
		'size' => 60,
		'opt' => 2 },
	      { 'name' => 'city',
		'size' => 40,
		'opt' => 0 },
	      { 'name' => 'stateprovincechoice',
		'choices' => [ [ 'S', 'State' ], [ 'P', 'Province' ] ],
		'opt' => 1 },
	      { 'name' => 'stateprovince',
		'size' => 40,
		'opt' => 1 },
	      { 'name' => 'postalcode',
		'size' => 20,
		'opt' => 1 },
	      { 'name' => 'country',
		'choices' => [ map { [ $_->[1], $_->[0] ] }
				   &list_countries() ],
		'opt' => 0 },
	      { 'name' => 'emailaddress',
		'size' => 60,
		'opt' => 0 },
	      { 'name' => 'phone',
		'size' => 40,
		'opt' => 0 },
	      { 'name' => 'fax',
		'size' => 40,
		'opt' => 1 },
	);
return @rv;
}

sub can_domain
{
local ($dname) = @_;
return 1 if ($access{'registrar'});
local @doms = split(/\s+/, $access{'doms'});
return &indexof($dname, @doms) >= 0;
}

# can_contacts(&domain)
# Returns 1 if the current user is allowed to edit contacts for a domain
sub can_contacts
{
return &virtual_server::master_admin() ? 1 : $config{'can_contacts'};
}

# get_domain_nameservers(&account, &domain)
# Returns an array ref of nameservers to use for some domain, or an error
# message
sub get_domain_nameservers
{
local ($account, $d) = @_;
if ($account->{'ns'}) {
	# Account-specific override given .. use it
	return [ split(/\s+/, $account->{'ns'}) ];
	}

local $z = &virtual_server::get_bind_zone($d->{'dom'});
if (!$z) {
	return $text{'rcom_ezone'};
	}
local $file = &bind8::find("file", $z->{'members'});
local @recs = &bind8::read_zone_file($file->{'values'}->[0], $d->{'dom'});
if (!@recs) {
	return &text('rcom_ezonefile', $file->{'values'}->[0]);
	}
local @ns;
foreach my $r (@recs) {
	if ($r->{'type'} eq 'NS' &&
	    $r->{'name'} eq $d->{'dom'}.".") {
		local $ns = $r->{'values'}->[0];
		if ($ns !~ /\.$/) {
			$ns .= ".".$d->{'dom'};
			}
		else {
			$ns =~ s/\.$//;
			}
		push(@ns, $ns);
		}
	}
return \@ns;
}

# list_countries()
# Returns a list of array refs, each of which contains a country name,
# two-letter code, three-letter code and DNS suffix.
# From: http://schmidt.devlib.org/data/countries.txt
sub list_countries
{
local @rv;
open(COUNTRIES, "$module_root_directory/countries.txt");
while(<COUNTRIES>) {
	s/\r|\n//g;
	local ($n, $name, $two, $three, $un, $sov, $exists, $owner, $tld) =
		split(/;/, $_);
	if ($exists) {
		push(@rv, [ $name, $two, $three, $tld ]);
		}
	}
close(COUNTRIES);
return sort { $a->[0] cmp $b->[0] } @rv;
}

# get_default_nameservers()
# Returns a list of nameserver hostnames that Virtualmin will use for
# new DNS domains. They won't have . at the end.
sub get_default_nameservers
{
&virtual_server::require_bind();
local $tmpl = &virtual_server::get_template(0);
local $tmaster = $tmpl->{'dns_master'} eq 'none' ? undef :
                                        $tmpl->{'dns_master'};
local $master = $tmaster ||
		$bind8::config{'default_prins'} ||
		&get_system_hostname();
$master =~ s/\.$//;
local @rv;
push(@rv, $master);
local @slaves = &bind8::list_slave_servers();
foreach my $slave (@slaves) {
	local @bn = $slave->{'nsname'} ? ( $slave->{'nsname'} )
				       : gethostbyname($slave->{'host'});
	push(@rv, $bn[0]);
	}
return @rv;
}

1;

