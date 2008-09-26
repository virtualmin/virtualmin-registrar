# Functions for talking to the Distribute.IT API

$distribute_api_url = "https://www.distributeit.com.au/api/";
%distribute_error_map = (
	"100", "Missing parameters",
	"101", "API Site not currently functioning",
	"102", "Authentication Failure",
	"103", "Account has been disabled",
	"104", "User has been disabled",
	"105", "Request coming from incorrect IP address.",
	"108", "Account Balance could not be obtained as account is Invoice based",
	"201", "Invalid or not supplied 'Type' parameter",
	"202", "Your Account has not been enabled for this 'Type'",
	"203", "Invalid or not supplied 'Action/Object parameter/s",
	"301", "Invalid Order ID.",
	"302", "Domain not supplied.",
	"303", "Domain Pricing table not set up for your account.",
	"304", "Domain not available for Registration.",
	"305", "Domain is not renewable.",
	"306", "Domain is not transferable.",
	"307", "Incorrect Domain Password",
	"308", "Domain UserID or Password not supplied",
	"309", "Invalid Domain Extension",
	"310", "Domain does not exist, has been deleted or transferred away",
	"311", "Domain does not exist in your reseller profile",
	"312", "Supplied UserID and Password do not match the domain.",
	"401", "Connection to Registry failed - retry.",
	"500", "Pre-Paid balance is not enough to cover order cost.",
	"501", "Invalid credit card type. See Appendix G.",
	"502", "Invalid credit card number.",
	"503", "Invalid credit card expiry date.",
	"504", "Credit Card amount plus the current pre-paid balance is not sufficient to cover the cost of the order.",
	"505", "Error with credit card transaction at bank.",
	"600", "Error with one or more fields when creating a Domain Contact.",
	"601", "Error with one or more fields when creating, renewing or transferring a Domain.",
	"602", "Error with one or more fields associated with a Host.",
	"603", "Error with one or more fields associated with Eligibility fields.",
	"604", "Error with one or more fields associated with a Nameserver.",
	"610", "Error connecting to registry",
	"611", "Domain cannot be Renewed or Transferred",
	"612", "Locking is not available for this domain",
	"613", "Domain Status prevents changing of domain lock",
	);

# Returns the name of this registrar
sub type_distribute_desc
{
return $text{'type_distribute'};
}

# type_distribute_domains(&account)
# Returns a list of TLDs that can be used with Distribute IT. Hard-coded for
# now, as I don't know of any programatic way to get this.
sub type_distribute_domains
{
return (".com", ".net", ".org", ".biz", ".info", ".com.au", ".net.au",
	".org.au", ".asn.au", ".id.au", ".co.uk", ".org.uk", ".co.nz",
	".ac.nz", ".gen.nz", ".geek.nz", ".maori.nz", ".net.nz", ".org.nz",
	".school.nz", ".cn", ".tv", ".ca", ".cc", ".name", ".vic.au", ".mobi",
	".asia", ".hk", ".com.my", ".net.my", ".org.my", ".vn", ".com.vn",
	".net.vn", ".biz.vn", ".org.vn", ".info.vn", ".name.vn", ".sg",
	".ph", ".com.ph", ".net.ph", ".org.ph", ".jp", ".in", ".co.in",
	".kr", ".co.kr", ".tw", ".md");
}

# type_distribute_edit_inputs(&account, new?)
# Returns table fields for entering the account login details
sub type_distribute_edit_inputs
{
local ($account, $new) = @_;
local $rv;
$rv .= &ui_table_row($text{'distribute_account'},
	&ui_textbox("distribute_account",
		    $account->{'distribute_account'}, 10));
$rv .= &ui_table_row($text{'distribute_user'},
	&ui_textbox("distribute_user", $account->{'distribute_user'}, 30));
$rv .= &ui_table_row($text{'distribute_pass'},
	&ui_textbox("distribute_pass", $account->{'distribute_pass'}, 30));
$rv .= &ui_table_row($text{'rcom_years'},
	&ui_opt_textbox("distribute_years", $account->{'distribute_years'},
			4, $text{'rcom_yearsdef'}));
return $rv;
}

# type_distribute_edit_parse(&account, new?, &in)
# Updates the account object with parsed inputs. Returns undef on success or
# an error message on failure.
sub type_distribute_edit_parse
{
local ($account, $new, $in) = @_;
$in->{'distribute_account'} =~ /^\d+$/ || return $text{'distribute_eaccount'};
$account->{'distribute_account'} = $in->{'distribute_account'};
$in->{'distribute_user'} =~ /^\S+$/ || return $text{'distribute_euser'};
$account->{'distribute_user'} = $in->{'distribute_user'};
$in->{'distribute_pass'} =~ /^\S+$/ || return $text{'distribute_epass'};
$account->{'distribute_pass'} = $in->{'distribute_pass'};
if ($in->{'distribute_years_def'}) {
	delete($account->{'distribute_years'});
	}
else {
	$in->{'distribute_years'} =~ /^\d+$/ && $in->{'distribute_years'} > 0 &&
	  $in->{'distribute_years'} <= 10 || return $text{'rcom_eyears'};
	$account->{'distribute_years'} = $in->{'distribute_years'};
	}
return undef;
}

# type_distribute_renew_years(&account, &domain)
# Returns the number of years by default to renew a domain for
sub type_distribute_renew_years
{
local ($account, $d) = @_;
return $account->{'distribute_years'} || 2;
}

# type_distribute_validate(&account)
# Checks if an account's details are vaid. Returns undef if OK or an error
# message if the login or password are wrong.
sub type_distribute_validate
{
local ($account) = @_;
local ($ok, $sid) = &connect_distribute_api($account, 1);
return $ok ? undef : $sid;
}

# type_distribute_check_domain(&account, domain)
# Checks if some domain name is available for registration, returns undef if
# yes, or an error message if not.
sub type_distribute_check_domain
{
local ($account, $dname) = @_;
local ($ok, $sid) = &connect_distribute_api($account, 1);
return &text('distribute_error', $sid) if (!$ok);
local ($ok, $out) = &call_distribute_api(
	$sid, "query", { 'Type' => 'Domains',
			 'Object' => 'Domain',
			 'Action' => 'Availability',
			 'Domain' => $dname });
# XXX not working??
print STDERR "ok=$ok out=$out\n";
return &text('distribute_taken', "$1") if (!$ok && $out =~ /304,(.*)/);
return &text('distribute_error', $out) if (!$ok);
return undef;
}

# type_distribute_owned_domain(&account, domain, [id])
# Checks if some domain is owned by the given account. If so, returns the
# 1 and the registrar's ID - if not, returns 1 and undef, on failure returns
# 0 and an error message.
sub type_distribute_owned_domain
{
local ($account, $dname, $id) = @_;
local ($ok, $sid) = &connect_distribute_api($account, 1);
return &text('distribute_error', $sid) if (!$ok);
local ($ok, $out) = &call_distribute_api(
	 $sid, "query", { 'Type' => 'Domains',
                          'Object' => 'Domain',
                          'Action' => 'Details',
			  'Domain' => $dname });
# XXX how to get domain ID?
return !$ok && $out =~ /310/ ? (1, undef) :
       !$ok ? (0, $out) : (1, $domid);
}

# type_distribute_create_domain(&account, &domain)
# Actually register a domain, if possible. Returns 0 and an error message if
# it failed, or 1 and an ID for the domain on success.
sub type_distribute_create_domain
{
local ($account, $d) = @_;
local ($ok, $sid) = &connect_distribute_api($account, 1);
return &text('distribute_error', $sid) if (!$ok);

# NS records come from the DNS domain
local $nss = &get_domain_nameservers($account, $d);
if (!ref($nss)) {
	return (0, $nss);
	}
elsif (!@$nss) {
	return (0, $text{'rcom_ensrecords'});
	}
elsif (@$nss < 2) {
	return (0, &text('distribute_enstwo', 2, $nss->[0]));
	}

# Create parameters
local $conid = $account->{'distribute_account'};
local %params = ( 'Type' => 'Domains',
		  'Object' => 'Domain',
		  'Action' => 'Create',
		  'Domain' => $d->{'dom'},
		  'UserID' => $d->{'user'},
		  'Password' => $d->{'pass'},
		  'Host' => $nss,
		  'OwnerContactID' => $conid,
		  'AdministrationContactID' => $conid,
		  'TechnicalContactID' => $conid,
		  'BillingContactID' => $conid,
		);
if ($account->{'distribute_period'}) {
	$params{'Period'} = $account->{'distribute_period'};
	}

# Create it
local ($ok, $out) = &call_distribute_api($sid, "order", \%params);
if ($ok) {
	# Done, and got order ID
	return (1, $out);
	}
else {
	return (0, $out);
	}
}

# type_distribute_delete_domain(&account, &domain)
# Deletes a domain previously created with this registrar
sub type_distribute_delete_domain
{
local ($account, $d) = @_;
local ($ok, $sid) = &connect_distribute_api($account, 1);
return &text('distribute_error', $sid) if (!$ok);

local ($ok, $out) = &call_distribute_api(
	$sid, "order", { 'Type' => 'Domains',
			 'Object' => 'Domain',
			 'Action' => 'Cancel',
			 'OrderID' => $d->{'registrar_id'} });
return ($ok, $out);
}

# connect_distribute_api(&account, return-error)
# Login to the API, and return 1 and a session ID or 0 and an error message
sub connect_distribute_api
{
local ($account, $reterr) = @_;
local ($ok, $sid) = &call_distribute_api(
	undef, "auth", { 'AccountNo' => $account->{'distribute_account'},
			 'UserId' => $account->{'distribute_user'},
			 'Password' => $account->{'distribute_pass'} });
&error("Distribute IT login failed : $sid") if (!$ok && !$reterr);
return ($ok, $sid);
}

# call_distribute_api(session-id, program, &params)
# Calls the API via an HTTP request, and returns either 1 and the output or
# 0 and an error message
sub call_distribute_api
{
local ($sid, $prog, $params) = @_;
local ($host, $port, $page, $ssl) = &parse_http_url($distribute_api_url);
$params ||= { };
if ($sid) {
	$params->{'SessionID'} = $sid;
	}
$page .= $prog.".pl";
local @params;
foreach my $k (keys %$params) {
	my $v = $params->{$k};
	foreach my $vv (ref($v) ? @$v : ( $v )) {
		push(@params, &urlize($k)."=".&urlize($vv));
		}
	}
$page .= "?".join("&", @params);
local ($out, $err);
print STDERR "page=$page\n";
&http_download($host, $port, $page, \$out, \$err, undef, $ssl);
if ($err =~ /403/) {
	# Bad IP .. warn specifically
	return (0, $text{'distribute_eip'});
	}
elsif ($err) {
	# Some other HTTP error
	return (0, $err);
	}
if ($out =~ /^((\S+):\s+)?OK:\s*([\000-\377]*)/) {
	# Valid response
	return (1, $3, $2);
	}
elsif ($out =~ /^((\S+):\s+)?ERR:\s*([\000-\377]*)/) {
	# Valid error
	local ($ecode, $dname) = ($3, $2);
	if ($ecode =~ /^(\d+)(.*)$/ && $distribute_error_map{$1}) {
		$ecode = $1." - ".$distribute_error_map{$1}.$2;
		}
	return (0, $ecode, $dname);
	}
else {
	# Some other output??
	return (0, "Unknown error : $out");
	}
}

1;

