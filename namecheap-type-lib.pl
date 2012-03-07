# Functions for talking to namecheap

$namecheap_api_url_test = "https://api.sandbox.namecheap.com/xml.response";
$namecheap_api_url = "https://api.namecheap.com/xml.response";

$@ = undef;
eval "use XML::Simple";
$xml_simple_err = $@;

# Returns the name of this registrar
sub type_namecheap_desc
{
return $text{'type_namecheap'};
}

# Returns an error message if needed dependencies are missing
sub type_namecheap_check
{
if ($xml_simple_err) {
	local $rv = &text('namecheap_eperl', "<tt>XML::Simple</tt>",
		     "<tt>".&html_escape($frontier_client_err)."</tt>");
	if (&foreign_available("cpan")) {
		$rv .= "\n".&text('gandi_cpan',
			"../cpan/download.cgi?source=3&cpan=XML::Simple&".
			"return=../$module_name/&".
			"returndesc=".&urlize($text{'index_return'}));
		}
	return $rv;
	}
return undef;
}

# type_namecheap_domains([&account])
# Returns top-level domains namecheap supports.
# From : http://www.namecheap.com/domains/domain-pricing.aspx
sub type_namecheap_domains
{
local ($account) = @_;
if ($account) {
	local ($ok, $xml) = &call_namecheap_api(
				$account, "namecheap.domains.getTldList");
	if ($ok) {
		return map { ".".$_->{'Name'} } @{$xml->{'Tlds'}->{'Tld'}};
		}
	}
return ( ".com", ".net", ".org", ".info", ".co.uk", ".us", ".me",
	 ".co", ".ca", ".mobi", ".biz", ".xxx", ".de". ".tv",
	 ".eu", ".in", ".org.uk", ".me.uk", ".cc", ".asia", ".ws",
	 ".bz", ".cm", ".nu" );
}

# type_namecheap_edit_inputs(&account, new?)
# Returns table fields for entering the account login details
sub type_namecheap_edit_inputs
{
local ($account, $new) = @_;
local $rv;
$rv .= &ui_table_row($text{'namecheap_user'},
	&ui_textbox("namecheap_user", $account->{'namecheap_user'}, 30));
$rv .= &ui_table_row($text{'namecheap_apikey'},
	&ui_textbox("namecheap_apikey", $account->{'namecheap_apikey'}, 30));
$rv .= &ui_table_row($text{'namecheap_srcdom'},
	&ui_textbox("namecheap_srcdom", $account->{'namecheap_srcdom'}, 30));
$rv .= &ui_table_row($text{'rcom_years'},
	&ui_opt_textbox("namecheap_years", $account->{'namecheap_years'},
			4, $text{'rcom_yearsdef'}));
$rv .= &ui_table_row($text{'rcom_test'},
	&ui_radio("namecheap_test", int($account->{'namecheap_test'}),
		  [ [ 1, $text{'rcom_test1'} ], [ 0, $text{'rcom_test0'} ] ]));
return $rv;
}

# type_namecheap_edit_parse(&account, new?, &in)
# Updates the account object with parsed inputs. Returns undef on success or
# an error message on failure.
sub type_namecheap_edit_parse
{
local ($account, $new, $in) = @_;
$in->{'namecheap_user'} =~ /^\S+$/ || return $text{'namecheap_euser'};
$account->{'namecheap_user'} = $in->{'namecheap_user'};
$in->{'namecheap_apikey'} =~ /^\S+$/ || return $text{'namecheap_eapikey'};
$account->{'namecheap_apikey'} = $in->{'namecheap_apikey'};
$in->{'namecheap_srcdom'} =~ /^\S+$/ || return $text{'namecheap_esrcdom'};
$account->{'namecheap_srcdom'} = $in->{'namecheap_srcdom'};
if ($in->{'namecheap_years_def'}) {
	delete($account->{'namecheap_years'});
	}
else {
	$in->{'namecheap_years'} =~ /^\d+$/ && $in->{'namecheap_years'} > 0 &&
	  $in->{'namecheap_years'} <= 10 || return $text{'rcom_eyears'};
	$account->{'namecheap_years'} = $in->{'namecheap_years'};
	}
$account->{'namecheap_test'} = $in->{'namecheap_test'};
return undef;
}

# type_namecheap_renew_years(&account, &domain)
# Returns the number of years by default to renew a domain for
sub type_namecheap_renew_years
{
local ($account, $d) = @_;
return $account->{'namecheap_years'} || 2;
}

# type_namecheap_validate(&account)
# Checks if an account's details are vaid. Returns undef if OK or an error
# message if the login or password are wrong.
sub type_namecheap_validate
{
local ($account) = @_;
local ($ok, $xml) = &call_namecheap_api($account,
			"namecheap.domains.getList");
if ($ok) {
	# Connected OK .. but does the source domain exist?
	local ($ok, $xml) = &call_namecheap_api($account,
			"namecheap.domains.getContacts",
			{ 'DomainName' => $account->{'namecheap_srcdom'} });
	if (!$ok && $xml =~ /Domain Name not found/i) {
		return $text{'namecheap_esrcdom2'};
		}
	elsif (!$ok) {
		return &text('namecheap_esrcdom3', $xml);
		}
	else {
		return undef;
		}
	}
else {
	return $xml;
	}
}

# type_namecheap_check_domain(&account, domain)
# Checks if some domain name is available for registration, returns undef if
# yes, or an error message if not.
sub type_namecheap_check_domain
{
local ($account, $dname) = @_;
local ($ok, $xml) = &call_namecheap_api($account, "namecheap.domains.check",
					{ 'DomainList' => $dname });
return &text('namecheap_error', $xml) if (!$ok);
if ($xml->{'DomainCheckResult'}->{'Available'} eq 'true') {
	return undef;
	}
elsif ($xml->{'DomainCheckResult'}->{'Available'}) {
	return $text{'namecheap_taken'};
	}
else {
	return $text{'namecheap_unknown'};
	}
}

# call_namecheap_api(&account, command, &params)
# Calls the namecheap API, and returns a status code and either error message
# or a results object.
sub call_namecheap_api
{
local ($account, $cmd, $params) = @_;
local $url = $account->{'namecheap_test'} ? $namecheap_api_url_test
					  : $namecheap_api_url;
local ($host, $port, $page, $ssl) = &parse_http_url($url);
$page .= "?APIUser=".&urlize($account->{'namecheap_user'}).
	 "&ApiKey=".&urlize($account->{'namecheap_apikey'}).
	 "&UserName=".&urlize($account->{'namecheap_user'}).
	 "&ClientIP=".($account->{'namecheap_ip'} ||
		       &virtual_server::get_dns_ip() ||
		       &virtual_server::get_default_ip()).
	 "&Command=".&urlize($cmd);
if ($params) {
	foreach my $p (keys %$params) {
		$page .= "&".$p."=".&urlize($params->{$p});
		}
	}
local ($out, $err);
&http_download($host, $port, $page, \$out, \$err, undef, $ssl);
return (0, $err) if ($err);
local $xml;
eval {
	$xml = XMLin(\$out);
	};
return (0, "Invalid response XML : $@") if ($@);
use Data::Dumper;
print STDERR Dumper($xml);
return (0, "API command failed : $xml->{'Errors'}->{'Error'}->{'content'}")
	if ($xml->{'Status'} ne 'OK');
return (1, $xml->{'CommandResponse'});
}

1;
