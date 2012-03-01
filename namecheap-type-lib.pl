# Functions for talking to namecheap

$namecheap_api_url_test = "https://api.sandbox.namecheap.com/xml.response";
$namecheap_api_url = "https://api.namecheap.com/xml.response";

# Returns the name of this registrar
sub type_namecheap_desc
{
return $text{'type_namecheap'};
}

# Returns an error message if needed dependencies are missing
sub type_namecheap_check
{
return undef;
}

# type_namecheap_domains([&account])
# Returns top-level domains namecheap supports.
# From : http://www.namecheap.com/domains/domain-pricing.aspx
sub type_namecheap_domains
{
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
	&ui_textbox("namecheap_user", $user->{'namecheap_user'}, 30));
$rv .= &ui_table_row($text{'namecheap_apikey'},
	&ui_textbox("namecheap_apikey", $account->{'namecheap_apikey'}, 30));
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
$user->{'namecheap_user'} = $in->{'namecheap_user'};
$in->{'namecheap_apikey'} =~ /^\S+$/ || return $text{'namecheap_eapikey'};
$account->{'namecheap_apikey'} = $in->{'namecheap_apikey'};
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

1;
