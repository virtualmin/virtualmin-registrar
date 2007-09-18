# Functions for talking to register.com

$rcom_api_hostname = "partnertest.rcomexpress.com";
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

# call_rcom_api(&account, command, &args)
# Calls a register.com API method, and returns a status code (1 for success, 0
# for error), the response text, and the response hash
sub call_rcom_api
{
local ($account, $cmd, $args) = @_;
local ($out, $err);
&http_download($rcom_api_hostname,
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

