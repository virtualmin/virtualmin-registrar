# Functions for talking to the Distribute.IT API

$distribute_api_url = "https://www.distributeit.com.au/api/";

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
	$sid, { 'Type' => 'Domains',
		'Object' => 'Domain',
		'Action' => 'Availability',
		'Domain' => $dname });
return &text('distribute_taken', "$1") if (!$ok && $out =~ /304,(.*)/);
return &text('distribute_error', $out) if (!$ok);
return undef;
}

# connect_distribute_api(&account, return-error)
# Login to the API, and return 1 and a session ID or 0 and an error message
sub connect_distribute_api
{
local ($account, $reterr) = @_;
local ($ok, $sid) = &call_distribute_api(
	undef, { 'AccountNo' => $account->{'distribute_account'},
		 'UserId' => $account->{'distribute_user'},
		 'Password' => $account->{'distribute_pass'} });
&error("Distribute IT login failed : $sid") if (!$ok && !$reterr);
return ($ok, $sid);
}

# call_distribute_api(session-id, &params)
# Calls the API via an HTTP request, and returns either 1 and the output or
# 0 and an error message
sub call_distribute_api
{
local ($sid, $params) = @_;
local ($host, $port, $page, $ssl) = &parse_http_url($distribute_api_url);
$params ||= { };
if ($sid) {
	$params->{'SessionID'} = $sid;
	}
$page .= "?".join("&", map { &urlize($_)."=".&urlize($params->{$_}) }
			   keys %$params);
local ($out, $err);
&http_download($host, $port, $page, \$out, \$err, undef, $ssl);
if ($err =~ /403/) {
	# Bad IP .. warn specifically
	return (0, $text{'distribute_eip'});
	}
elsif ($err) {
	# Some other HTTP error
	return (0, $err);
	}
if ($out =~ /^OK:\s*(.*)/) {
	# Valid response
	return (1, $1);
	}
elsif ($out =~ /^ERR:\s*(.*)$/) {
	# Valid error
	return (0, $1);
	}
else {
	# Some other output??
	return (0, "Unknown error : $out");
	}
}

1;

