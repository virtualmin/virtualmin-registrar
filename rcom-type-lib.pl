# Functions for talking to register.com

$rcom_api_hostname = "partner.rcomexpress.com";
$rcom_test_api_hostname = "partnertest.rcomexpress.com";
$rcom_api_port = 80;
$rcom_api_page = "/interface.asp";
@rcom_card_types = ( "visa", "amex", "mastercard" );

use Time::Local;

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

# type_rcom_create_inputs()
# Returns HTML for creating a new register.com sub-account. 
sub type_rcom_create_inputs
{
local $rv;
local @countries = &list_countries();
local ($defc) = grep { $_->[1] eq "US" } @countries;
$rv .= &ui_table_row($text{'rcom_newuid'},
	&ui_textbox("newuid", undef, 20));
$rv .= &ui_table_row($text{'rcom_newpw'},
	&ui_password("newpw", undef, 20));

# Company and personal name
$rv .= &ui_table_row($text{'rcom_organizationname'},
	&ui_textbox("organizationname", undef, 60));
$rv .= &ui_table_row($text{'rcom_jobtitle'},
	&ui_opt_textbox("jobtitle", undef, 40, $text{'rcom_none'}));
$rv .= &ui_table_row($text{'rcom_firstname'},
	&ui_textbox("firstname", undef, 40));
$rv .= &ui_table_row($text{'rcom_lastname'},
	&ui_textbox("lastname", undef, 40));

# Address and phone
$rv .= &ui_table_hr();
$rv .= &ui_table_row($text{'rcom_address'},
	&ui_textbox("address1", undef, 60)."<br>\n".
	&ui_textbox("address2", undef, 60));
$rv .= &ui_table_row($text{'rcom_city'},
	&ui_textbox("city", undef, 40));
$rv .= &ui_table_row($text{'rcom_postalcode'},
	&ui_textbox("postalcode", undef, 10));
$rv .= &ui_table_row($text{'rcom_stateprovince'},
	&ui_select("stateprovincechoice", "S",
		   [ [ "S", $text{'rcom_state'} ],
		     [ "P", $text{'rcom_province'} ] ]).
	&ui_textbox("stateprovince", undef, 40));
$rv .= &ui_table_row($text{'rcom_country'},
	&ui_select("country", $defc->[0],
		[ map { [ $_->[0] ] } @countries ]));
$rv .= &ui_table_row($text{'rcom_phone'},
	&ui_textbox("phone", undef, 20));
$rv .= &ui_table_row($text{'rcom_fax'},
	&ui_opt_textbox("fax", undef, 20, $text{'rcom_none'}));
$rv .= &ui_table_row($text{'rcom_email'},
	&ui_textbox("email", undef, 60));

# Credit card
$rv .= &ui_table_hr();
$rv .= &ui_table_row($text{'rcom_cardtype'},
	&ui_select("cardtype", undef,
		   [ map { [ $_, $text{'rcom_cardtype_'.$_} ] }
			 @rcom_card_types ]));
$rv .= &ui_table_row($text{'rcom_ccname'},
	&ui_textbox("ccname", undef, 60));
$rv .= &ui_table_row($text{'rcom_creditcardnumber'},
	&ui_textbox("creditcardnumber", undef, 60));
$rv .= &ui_table_row($text{'rcom_creditcardexp'},
	&ui_textbox("creditcardexpmonth", undef, 2)."/".
	&ui_textbox("creditcardexpyear", undef, 4));
$rv .= &ui_table_row($text{'rcom_cvv2'},
	&ui_textbox("cvv2", undef, 3));
$rv .= &ui_table_row($text{'rcom_ccaddress'},
	&ui_textbox("ccaddress", undef, 60));
$rv .= &ui_table_row($text{'rcom_cczip'},
	&ui_textbox("cczip", undef, 10));
$rv .= &ui_table_row($text{'rcom_cccountry'},
	&ui_select("cccountry", $defc->[0],
		[ map { [ $_->[0] ] } @countries ]));

return $rv;
}

# type_rcom_create_parse(&account, &in)
# Updates the account objcet with values parsed from in. Returns undef if all
# OK, or an error message on failure.
sub type_rcom_create_parse
{
local ($account, $in) = @_;

# Username and password
$in->{'newuid'} =~ /^[a-z0-9\.\-\_]+$/ || return $text{'rcom_enewuid'};
$account->{'rcom_newuid'} = $in->{'newuid'};
$in->{'newpw'} =~ /^\S+$/ || return $text{'rcom_enewpw'};
$account->{'rcom_newpw'} = $in->{'newpw'};

# XXX
}

# type_rcom_create_account(&account)
# Actually does the work of creating a new register.com sub-account, which will
# be under the main Virtualmin account but billed separately.
sub type_rcom_create_account
{
local ($account) = @_;

# Make HTTP request to virtualmin.com, where a CGI knows our master password

# If OK, clear un-needed details from the account object

return undef;
}

# type_rcom_renew_years(&account, &domain)
# Returns the number of years by default to renew a domain for
sub type_rcom_renew_years
{
local ($account, $d) = @_;
return $account->{'rcom_years'} || 2;
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

# type_rcom_get_expiry(&account, &domain)
# Returns either 1 and the expiry time (unix) for a domain, or 0 and an error
# message.
sub type_rcom_get_expiry
{
local ($account, $d) = @_;
$d->{'dom'} =~ /^([^\.]+)\.(\S+)$/ || return (0, $text{'rcom_etld'});
local ($sld, $tld) = ($1, $2);
local ($ok, $out, $resp) = &call_rcom_api($account, "GetDomainExp",
				{ 'SLD' => $sld, 'TLD' => $tld });
if (!$ok) {
	return (0, $out);
	}
elsif ($resp->{'ExpirationDate'} !~ /^(\d+)\/(\d+)\/(\d+)\s+(\d+):(\d+):(\d+)\s+(\S+)/) {
	return (0, &text('rcom_edate', $resp->{'ExpirationDate'}));
	}
else {
	return (1, eval { timelocal($6, $5, $4+($7 eq "PM" ? 12 : 0),
				$2, $1-1, $3-1900) });
	return (0, $@);
	}
}

# type_rcom_renew_domain(&account, &domain, years)
# Attempts to renew a domain for the specified period. Returns 1 and the
# registrars confirmation code on success, or 0 and an error message on
# failure.
sub type_rcom_renew_domain
{
local ($account, $d, $years) = @_;
local ($account, $d) = @_;
$d->{'dom'} =~ /^([^\.]+)\.(\S+)$/ || return (0, $text{'rcom_etld'});
local ($sld, $tld) = ($1, $2);
local ($ok, $out, $resp) = &call_rcom_api($account, "Extend",
				{ 'SLD' => $sld, 'TLD' => $tld,
				  'NumYears' => $years });
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

