# Functions for talking to register.com

$rcom_api_hostname = "partner.rcomexpress.com";
$rcom_test_api_hostname = "partnertest.rcomexpress.com";
$rcom_api_port = 80;
$rcom_api_page = "/interface.asp";

# Returns the name of this registrar
sub type_rcom_desc
{
return $text{'type_rcom'};
}

# type_rcom_edit_inputs(&account, new?)
# Returns table fields for entering the account login details
sub type_rcom_edit_inputs
{
local ($account, $new) = @_;
local $rv;
$rv .= &ui_table_row($text{'rcom_account'},
	&ui_textbox("rcom_account", $account->{'rcom_account'}, 30));
$rv .= &ui_table_row($text{'rcom_pass'},
	&ui_textbox("rcom_pass", $account->{'rcom_pass'}, 30));
$rv .= &ui_table_row($text{'rcom_test'},
	&ui_radio("rcom_test", int($account->{'rcom_test'}),
		  [ [ 1, $text{'rcom_test1'} ],
		    [ 0, $text{'rcom_test0'} ] ]));
$rv .= &ui_table_row($text{'rcom_years'},
	&ui_opt_textbox("rcom_years", $account->{'rcom_years'},
			4, $text{'rcom_yearsdef'}));
return $rv;
}

# type_rcom_edit_parse(&account, new?, &in)
# Updates the account object with parsed inputs. Returns undef on success or
# an error message on failure.
sub type_rcom_edit_parse
{
local ($account, $new, $in) = @_;
$in->{'rcom_account'} =~ /^\S+$/ || return $text{'rcom_eaccount'};
$account->{'rcom_account'} = $in->{'rcom_account'};
$in->{'rcom_pass'} =~ /^\S+$/ || return $text{'rcom_epass'};
$account->{'rcom_pass'} = $in->{'rcom_pass'};
$account->{'rcom_test'} = $in->{'rcom_test'};
if ($in->{'rcom_years_def'}) {
	delete($account->{'rcom_years'});
	}
else {
	$in->{'rcom_years'} =~ /^\d+$/ && $in->{'rcom_years'} > 0 &&
	  $in->{'rcom_years'} <= 10 || return $text{'rcom_eyears'};
	$account->{'rcom_years'} = $in->{'rcom_years'};
	}
return undef;
}

# type_rcom_validate(&account)
# Checks if an account's details are vaid. Returns undef if OK or an error
# message if the login or password are wrong.
sub type_rcom_validate
{
local ($account) = @_;
local ($ok, $msg) = &call_rcom_api($account, "GetDomainCount", { });
if ($ok) {
	return undef;
	}
else {
	return $msg;
	}
}

# type_rcom_check_domain(&account, domain)
# Checks if some domain name is available for registration, returns undef if
# yes, or an error message if not.
sub type_rcom_check_domain
{
local ($account, $dname) = @_;
$dname =~ /^([^\.]+)\.(\S+)$/ || return 0;
local ($sld, $tld) = ($1, $2);
local ($ok, $out, $resp) = &call_rcom_api($account, "Check",
				{ 'SLD' => $sld, 'TLD' => $tld });
if (!$ok) {
	return $out;
	}
elsif ($resp->{'RRPCode'} == 210) {
	return undef;
	}
elsif ($resp->{'RRPCode'} == 211) {
	return $text{'rcom_taken'};
	}
else {
	return $resp->{'RRPText'} || "Unknown error";
	}
}

# type_rcom_owned_domain(&account, domain, [id])
# Checks if some domain is owned by the given account. If so, returns the
# 1 and the registrar's ID - if not, returns 1 and undef, on failure returns
# 0 and an error message.
sub type_rcom_owned_domain
{
local ($account, $dname, $id) = @_;
$dname =~ /^([^\.]+)\.(\S+)$/ || return (0, $text{'rcom_etld'});
local ($sld, $tld) = ($1, $2);
local ($ok, $out, $resp) = &call_rcom_api($account, "GetDomainInfo",
					  { 'SLD' => $sld, 'TLD' => $tld });
if (!$ok) {
	if ($out eq "Domain name not found") {
		return (1, undef);
		}
	else {
		return (0, $out || "Unknown error");
		}
	}
elsif ($resp->{'domainnameid'}) {
	return (1, $resp->{'domainnameid'});
	}
else {
	return (1, undef);
	}
}

# type_rcom_ensure_nameservers(&account, &domain, &nameservers)
# Registers a list of nameservers with the registrar. Returns undef if all OK,
# or an error mesage on failure.
sub type_rcom_ensure_nameservers
{
local ($account, $d, $nss) = @_;
foreach my $ns (&unique(@$nss)) {
	local ($ok, $out, $resp) = &call_rcom_api($account, "checknsstatus",
					{ 'checknsname' => $ns });
	next if ($ok);

	# need to add it
	local $nsip = &to_ipaddress($ns);
	$nsip || return (0, &text('rcom_elookupns', $ns));
	local ($ok, $out, $resp) = &call_rcom_api($account,
					"registernameserver",
					{ 'add' => 'true',
					  'nsname' => $ns,
					  'ip' => $nsip });
	if (!$ok) {
		return &text('rcom_eaddns', $ns, $out);
		}
	}
return undef;
}

# type_rcom_create_domain(&account, &domain)
# Actually register a domain, if possible. Returns 0 and an error message if
# it failed, or 1 and an ID for the domain on success.
sub type_rcom_create_domain
{
local ($account, $d) = @_;
$d->{'dom'} =~ /^([^\.]+)\.(\S+)$/ || return (0, $text{'rcom_etld'});
local ($sld, $tld) = ($1, $2);

# NS records come from the DNS domain
local $args = { 'SLD' => $sld, 'TLD' => $tld };
local $nss = &get_domain_nameservers($d);
if (!ref($nss)) {
	return (0, $nss);
	}
elsif (!@$nss) {
	return (0, $text{'rcom_ensrecords'});
	}
my $nscount = 1;
foreach my $ns (@$nss) {
	$args->{'NS'.$nscount++} = $ns;
	}

# check the if the nameservers have been added
local $err = &type_rcom_ensure_nameservers($account, $d, $nss);
return (0, $err) if ($err);

# Call the API to create
if ($account->{'rcom_years'}) {
	$args->{'NumYears'} = $account->{'rcom_years'};
	}
local ($ok, $out, $resp) = &call_rcom_api($account, "Purchase", $args);
if (!$ok) {
	return (0, $out);
	}
elsif ($resp->{'RRPCode'} != 200) {
	return (0, $resp->{'RRPText'});
	}
else {
	return (1, $resp->{'OrderID'});
	}
}

# type_rcom_set_nameservers(&account, &domain)
# Updates the nameservers for a domain to match DNS. Returns undef on success
# or an error message on failure.
sub type_rcom_set_nameservers
{
local ($account, $d) = @_;

# Get nameservers in DNS
local $nss = &get_domain_nameservers($d);
if (!ref($nss)) {
	return $nss;
	}
elsif (!@$nss) {
	return $text{'rcom_ensrecords'};
	}

# Make sure they are all available
local $err = &type_rcom_ensure_nameservers($account, $d, $nss);
return $err if ($err);

# Update for the domain
$d->{'dom'} =~ /^([^\.]+)\.(\S+)$/ || return $text{'rcom_etld'};
local $args = { 'SLD' => $1, 'TLD' => $2 };
my $nscount = 1;
foreach my $ns (@$nss) {
	$args->{'NS'.$nscount++} = $ns;
	}
local ($ok, $out, $resp) = &call_rcom_api($account, "ModifyNS", $args);
return $ok ? undef : $out;
}

# type_rcom_delete_domain(&account, &domain)
# Deletes a domain previously created with this registrar
sub type_rcom_delete_domain
{
local ($account, $d) = @_;
$d->{'dom'} =~ /^([^\.]+)\.(\S+)$/ || return (0, $text{'rcom_etld'});
local ($sld, $tld) = ($1, $2);
local $args = { 'SLD' => $sld, 'TLD' => $tld,
		'EndUserIP' => $ENV{'REMOTE_ADDR'} ||
			       &virtual_server::get_default_ip() };
local ($ok, $out, $resp) = &call_rcom_api($account, "DeleteRegistration",$args);
if (!$ok) {
	return (0, $out);
	}
elsif ($resp->{'domaindeleted'} ne 'True' &&
       $resp->{'RRPCode'} != 200) {
	return (0, $resp->{'RRPText'} || "Unknown error");
	}
else {
	return (1, undef);
	}
}

# type_rcom_get_contact(&account, &domain)
# Returns a array containing hashes of domain contact information, or an error
# message if it could not be found.
sub type_rcom_get_contact
{
local ($account, $d) = @_;
$d->{'dom'} =~ /^([^\.]+)\.(\S+)$/ || return $text{'rcom_etld'};
local ($sld, $tld) = ($1, $2);
local ($ok, $out, $resp) = &call_rcom_api($account, "GetContacts",
				{ 'SLD' => $sld, 'TLD' => $tld });
if (!$ok) {
	return $out;
	}
local @rv;
foreach my $ct ("Admin", "Tech") {
	local %con;
	foreach my $k (keys %$resp) {
		next if ($k !~ /^\Q$ct\E(.*)$/);
		next if ($1 eq "PartyID");	# Don't ever touch this
		$con{lc($1)} = $resp->{$k};
		$con{'lcmap'}->{lc($1)} = $1;
		}
	if (keys %con) {
		$con{'type'} = lc($ct);
		push(@rv, \%con);
		}
	}
return \@rv;
}

# type_rcom_save_contact(&account, &domain, &contacts)
# Updates contacts from an array of hashes
sub type_rcom_save_contact
{
local ($account, $d, $cons) = @_;
$d->{'dom'} =~ /^([^\.]+)\.(\S+)$/ || return $text{'rcom_etld'};
local ($sld, $tld) = ($1, $2);

foreach my $ct ("Admin", "Tech") {
	local ($con) = grep { $_->{'type'} eq lc($ct) } @$cons;
	next if (!$con);
	local $args = { 'SLD' => $sld, 'TLD' => $tld,
			'ContactType' => $ ct };
	foreach my $k (keys %$con) {
		if ($k ne "type" && $k ne "lcmap") {
			$args->{$ct.$con->{'lcmap'}->{$k}} = $con->{$k};
			}
		}
	local ($ok, $out, $resp) = &call_rcom_api($account, "Contacts", $args);
	if (!$ok) {
		return $out;
		}
	}
return undef;
}

# call_rcom_api(&account, command, &args)
# Calls a register.com API method, and returns a status code (1 for success, 0
# for error), the response text, and the response hash
sub call_rcom_api
{
local ($account, $cmd, $args) = @_;
local ($out, $err);
print STDERR "calling $cmd with ",
     (join("", map { "&".$_."=".&urlize($args->{$_}) } keys %$args)),"\n";
&http_download($account->{'rcom_test'} ? $rcom_test_api_hostname
				       : $rcom_api_hostname,
	       $rcom_api_port,
	       $rcom_api_page."?command=".&urlize($cmd).
	       "&uid=".&urlize($account->{'rcom_account'}).
	       "&pw=".&urlize($account->{'rcom_pass'}).
	       "&ResponseType=Text".
	       (join("", map { "&".$_."=".&urlize($args->{$_}) } keys %$args)),
	       \$out, \$error, undef, $rcom_api_ssl);
if ($error) {
	# HTTP error
	return (0, $error, undef);
	}
print STDERR "got $out\n";
# Parse response lines
local %resp;
foreach my $l (split(/\r?\n/, $out)) {
	$l =~ s/^\s*;.*//;
	if ($l =~ /^([^=]+)=(.*)/) {
		$resp{$1} = $2;
		}
	}
if ($resp{'ErrCount'}) {
	# Some error was returned
	local @errs;
	for(my $i=1; $i<=$resp{'ErrCount'}; $i++) {
		push(@errs, $resp{'Err'.$i});
		}
	return (0, join(", ", @errs) || "Unknown error : $out", \%resp);
	}
return (1, $out, \%resp);
}

1;

