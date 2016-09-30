# Common functions for domain registration
# XXX - List all domains from registrar
# XXX - OpenSRS support - FS#5098
use strict;
no strict 'refs';
use warnings;
our (%text, %config);
our $module_name;
our $module_config_directory;
our $module_root_directory;

BEGIN { push(@INC, ".."); };
eval "use WebminCore;";
&init_config();
&foreign_require("virtual-server", "virtual-server-lib.pl");
our $registrar_accounts_dir = "$module_config_directory/accounts";
our %access = &get_module_acl();
our $auto_cron_cmd = "$module_config_directory/auto.pl";
our $input_name = $module_name;
$input_name =~ s/[^A-Za-z0-9]/_/g;

# Bring in all register-type specific libraries
our @registrar_types = (
	{ 'name' => 'rcom',
	  'disabled' => 0,
	  'desc' => $text{'type_rcom'} },
	{ 'name' => 'gandi',
	  'disabled' => 0,
	  'desc' => $text{'type_gandi'} },
	{ 'name' => 'newgandi',
	  'disabled' => 0,
	  'desc' => $text{'type_newgandi'} },
	{ 'name' => 'distribute',
	  'disabled' => 1,
	  'desc' => $text{'type_distribute'} },
	{ 'name' => 'namecheap',
	  'disabled' => 0,
	  'desc' => $text{'type_namecheap'} },
    );
foreach my $t (@registrar_types) {
	do $t->{'name'}.'-type-lib.pl';
	}

# list_registrar_accounts
# Returns a list of registrar accounts that have been setup for use in
# this module.
sub list_registrar_accounts
{
my @rv;
opendir(DIR, $registrar_accounts_dir);
foreach my $f (readdir(DIR)) {
	next if ($f eq "." || $f eq "..");
	my %account;
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
my ($account) = @_;
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
my ($account) = @_;
&unlink_file("$registrar_accounts_dir/$account->{'id'}");
}

# find_registrar_account(domain)
# Returns the best registrar account for some domain
sub find_registrar_account
{
my ($dname) = @_;
foreach my $a (grep { $_->{'enabled'} } &list_registrar_accounts()) {
	# Does the registrar support this domain?
	my $tfunc = "type_".$a->{'registrar'}."_domains";
	if (defined(&$tfunc)) {
		my @doms = &$tfunc($a);
		if (@doms) {
			next if (!&in_tld_list($dname, \@doms));
			}
		}
	# Does the account want it?
	my @doms = split(/\s+/, $a->{'doms'});
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
my ($dname, $doms) = @_;
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
my ($account) = @_;
my @rv;
foreach my $d (&virtual_server::list_domains()) {
	push(@rv, $d) if ($d->{$module_name} &&
			  $d->{'registrar_account'} eq $account->{'id'});
	}
return @rv;
}

# get_contact_schema(&account, &domain, type, new?, class)
# Returns a list of fields for domain contacts
sub get_contact_schema
{
my ($account, $d, $type, $newcontact, $cls) = @_;
my $sfunc = "type_".$account->{'registrar'}."_get_contact_schema";
return &$sfunc($account, $d, $type, $newcontact, $cls);
}

sub can_domain
{
my ($dname) = @_;
return 1 if ($access{'registrar'});
my @doms = split(/\s+/, $access{'doms'});
return &indexof($dname, @doms) >= 0;
}

# can_contacts(&domain)
# Returns 1 if the current user is allowed to edit contacts for a domain,
# 2 for view only, 3 if selection of other contacts is also allowed
sub can_contacts
{
return &virtual_server::master_admin() ? 3 : $config{'can_contacts'};
}

# can_nameservers(&domain)
# Returns 1 if the current user is allowed to edit nameservers for a domain
sub can_nameservers
{
return &virtual_server::master_admin() ? 1 : $config{'can_nameservers'};
}

# get_domain_nameservers([&account], &domain)
# Returns an array ref of nameservers to use for some domain, or an error
# message
sub get_domain_nameservers
{
my ($account, $d) = @_;
if ($account && $account->{'ns'}) {
	# Account-specific override given .. use it
	return [ split(/\s+/, $account->{'ns'}) ];
	}

my $z = &virtual_server::get_bind_zone($d->{'dom'});
if (!$z) {
	return $text{'rcom_ezone'};
	}
my $file = &bind8::find("file", $z->{'members'});
my @recs = &bind8::read_zone_file($file->{'values'}->[0], $d->{'dom'});
if (!@recs) {
	return &text('rcom_ezonefile', $file->{'values'}->[0]);
	}
my @ns;
foreach my $r (@recs) {
	if ($r->{'type'} eq 'NS' &&
	    $r->{'name'} eq $d->{'dom'}.".") {
		my $ns = $r->{'values'}->[0];
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

# set_domain_nameservers(&domain, &nameservers)
# Updates the nameservers in a domain's zone file. Returns undef on success or
# an error message on failure.
sub set_domain_nameservers
{
my ($d, $nss) = @_;
&virtual_server::require_bind();

# Find the zone and records
my $z = &virtual_server::get_bind_zone($d->{'dom'});
if (!$z) {
        return $text{'rcom_ezone'};
        }
my $file = &bind8::find("file", $z->{'members'});
my $fn = $file->{'values'}->[0];
my @recs = &bind8::read_zone_file($file->{'values'}->[0], $d->{'dom'});
if (!@recs) {
        return &text('rcom_ezonefile', $file->{'values'}->[0]);
        }

# Remove existing NS records
my @oldns = grep { $_->{'type'} eq 'NS' &&
		      $_->{'name'} eq $d->{'dom'}."." } @recs;
foreach my $r (reverse(@oldns)) {
	&bind8::delete_record($fn, $r);
	}

# Add new NS records
foreach my $h (@$nss) {
	&bind8::create_record($fn, $d->{'dom'}.".", undef, "IN", "NS", $h.".");
	}

&bind8::bump_soa_record($fn, \@recs);
&virtual_server::register_post_action(\&virtual_server::restart_bind);
return undef;
}

# list_countries()
# Returns a list of array refs, each of which contains a country name,
# two-letter code, three-letter code and DNS suffix.
# From: http://schmidt.devlib.org/data/countries.txt
sub list_countries
{
my @rv;
open(my $COUNTRIES, "<", "$module_root_directory/countries.txt");
while(<$COUNTRIES>) {
	s/\r|\n//g;
	my ($n, $name, $two, $three, $un, $sov, $exists, $owner, $tld) =
		split(/;/, $_);
	if ($exists) {
		push(@rv, [ $name, $two, $three, $tld ]);
		}
	}
close($COUNTRIES);
return sort { $a->[0] cmp $b->[0] } @rv;
}

# get_default_nameservers()
# Returns a list of nameserver hostnames that Virtualmin will use for
# new DNS domains. They won't have . at the end.
sub get_default_nameservers
{
&virtual_server::require_bind();
my $tmpl = &virtual_server::get_template(0);
my $tmaster = $tmpl->{'dns_master'} eq 'none' ? undef :
                                        $tmpl->{'dns_master'};
no warnings "once";
my $master = $tmaster ||
		$bind8::config{'default_prins'} ||
		&get_system_hostname();
use warnings "once";
$master =~ s/\.$//;
my @rv;
push(@rv, $master);
my @slaves = &bind8::list_slave_servers();
foreach my $slave (@slaves) {
	my @bn = $slave->{'nsname'} ? ( $slave->{'nsname'} )
				       : gethostbyname($slave->{'host'});
	push(@rv, $bn[0]);
	}
return @rv;
}

# contact_hash_to_string(&contact)
# Returns a string version of a contact hash, for comparisons
sub contact_hash_to_string
{
my ($h) = @_;
my @k = sort { $a cmp $b }
	        grep { $_ ne "purpose" && $_ ne "lcmap" && $_ ne "id" &&
		       !ref($h->{$_}) } (keys %$h);
return join(" ", map { $_."=".$h->{$_} } @k);
}

# nice_contact_name(&contact, &account)
# Returns a human-readable name for a contact
sub nice_contact_name
{
my ($con, $account) = @_;
my $nfunc = "type_".$account->{'registrar'}."_nice_contact_name";
if (defined(&$nfunc)) {
	return &$nfunc($con);
	}
return $con->{'id'}." ".
       ($con->{'firstname'} || $con->{'FirstName'})." ".
       ($con->{'lastname'} || $con->{'LastName'});
}

1;
