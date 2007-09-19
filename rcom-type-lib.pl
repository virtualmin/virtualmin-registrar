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
local $z = &virtual_server::get_bind_zone($d->{'dom'});
if (!$z) {
	return (0, $text{'rcom_ezone'});
	}
local $file = &bind8::find("file", $z->{'members'});
local @recs = &bind8::read_zone_file($file->{'values'}->[0], $d->{'dom'});
local $nscount = 0;
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
		$nscount++;
		$args->{'NS'.$nscount} = $ns;
		push(@ns, $ns);
		}
	}
$nscount || return (0, $text{'rcom_ensrecords'});

# Check the if the nameservers have been added
foreach my $ns (&unique(@ns)) {
	local ($ok, $out, $resp) = &call_rcom_api($account, "CheckNSStatus",
					{ 'CheckNSName' => $ns });
	next if ($ok);

	# Need to add it
	local $nsip = &to_ipaddress($ns);
	$nsip || return (0, &text('rcom_elookupns', $ns));
	local ($ok, $out, $resp) = &call_rcom_api($account,
					"RegisterNameServer",
					{ 'Add' => 'true',
					  'NSName' => $ns,
					  'IP' => $nsip });
	if (!$ok) {
		return (0, &text('rcom_eaddns', $ns, $out));
		}
	}

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
foreach my $ct ("Tech", "Admin") {
	local %con;
	foreach my $k (keys %$resp) {
		next if ($k !~ /^\Q$ct\E(.*)$/);
		$con{lc($1)} = $resp->{$k};
		}
	if (keys %con) {
		$con{'type'} = lc($ct);
		push(@rv, \%con);
		}
	}
return \@rv;
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

