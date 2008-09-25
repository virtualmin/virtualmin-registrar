# Functions for talking to gandi.net

$gandi_api_url = "https://api.ote.gandi.net/xmlrpc/";

$@ = undef;
eval "use Frontier::Client";
$frontier_client_err = $@;

# Returns the name of this registrar
sub type_gandi_desc
{
return $text{'type_gandi'};
}

# Returns an error message if needed dependencies are missing
sub type_gandi_check
{
if ($frontier_client_err) {
	local $rv = &text('gandi_eperl', "<tt>Frontier::Client</tt>",
		     "<tt>".&html_escape($frontier_client_err)."</tt>");
	if (&foreign_available("cpan")) {
		$rv .= "\n".&text('gandi_cpan',
			"../cpan/download.cgi?source=3&cpan=Frontier::Client&".
			"return=../$module_name/&".
			"returndesc=".&urlize($text{'index_return'}));
		}
	return $rv;
	}
return undef;
}

# type_gandi_domains(&account)
# Returns a list of TLDs that can be used with gandi.net. Hard-coded for
# now, as I don't know of any programatic way to get this.
sub type_gandi_domains
{
return (".asia", ".biz", ".com", ".info", ".mobi", ".name", ".net",
	".org", ".pro", ".at", ".be", ".cc", ".ch", ".cn", ".co.uk",
	".cz", ".de", ".eu", ".fr", ".in", ".it", ".li", ".lu", ".me",
	".nu", ".org.uk", ".pl", ".re", ".tv", ".tw", ".us");
}

# type_gandi_edit_inputs(&account, new?)
# Returns table fields for entering the account login details
sub type_gandi_edit_inputs
{
local ($account, $new) = @_;
local $rv;
$rv .= &ui_table_row($text{'gandi_account'},
	&ui_textbox("gandi_account", $account->{'gandi_account'}, 30));
$rv .= &ui_table_row($text{'gandi_pass'},
	&ui_textbox("gandi_pass", $account->{'gandi_pass'}, 30));
$rv .= &ui_table_row($text{'rcom_years'},
	&ui_opt_textbox("gandi_years", $account->{'gandi_years'},
			4, $text{'rcom_yearsdef'}));
return $rv;
}

# type_gandi_edit_parse(&account, new?, &in)
# Updates the account object with parsed inputs. Returns undef on success or
# an error message on failure.
sub type_gandi_edit_parse
{
local ($account, $new, $in) = @_;
$in->{'gandi_account'} =~ /^\S+$/ || return $text{'gandi_eaccount'};
$account->{'gandi_account'} = $in->{'gandi_account'};
$in->{'gandi_pass'} =~ /^\S+$/ || return $text{'gandi_epass'};
$account->{'gandi_pass'} = $in->{'gandi_pass'};
if ($in->{'gandi_years_def'}) {
	delete($account->{'gandi_years'});
	}
else {
	$in->{'gandi_years'} =~ /^\d+$/ && $in->{'gandi_years'} > 0 &&
	  $in->{'gandi_years'} <= 10 || return $text{'rcom_eyears'};
	$account->{'gandi_years'} = $in->{'gandi_years'};
	}
return undef;
}

# type_gandi_renew_years(&account, &domain)
# Returns the number of years by default to renew a domain for
sub type_gandi_renew_years
{
local ($account, $d) = @_;
return $account->{'gandi_years'} || 2;
}

# type_gandi_validate(&account)
# Checks if an account's details are vaid. Returns undef if OK or an error
# message if the login or password are wrong.
sub type_gandi_validate
{
local ($account) = @_;
local ($server, $sid) = &connect_gandi_api($account, 1);
if ($server) {
	return undef;
	}
else {
	return $sid;
	}
}

# type_gandi_check_domain(&account, domain)
# Checks if some domain name is available for registration, returns undef if
# yes, or an error message if not.
sub type_gandi_check_domain
{
local ($account, $dname) = @_;
local ($server, $sid) = &connect_gandi_api($account, 1);
return &text('gandi_error', $sid) if (!$server);
local $avail;
eval {
	$avail = $server->call("domain_available", $sid, [ $dname ]);
	};
return &text('gandi_error', $@) if ($@);
return $avail->{$dname} && $avail->{$dname}->value() ?
	undef : $text{'gandi_taken'};
}

# type_gandi_owned_domain(&account, domain, [id])
# Checks if some domain is owned by the given account. If so, returns the
# 1 and the registrar's ID - if not, returns 1 and undef, on failure returns
# 0 and an error message.
sub type_gandi_owned_domain
{
local ($account, $dname, $id) = @_;
local ($server, $sid) = &connect_gandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Get the domain list
local $list;
eval {
	$list = $server->call("domain_list", $sid);
	};
return (0, &text('gandi_error', $@)) if ($@);

# Check if on list
foreach my $l (@$list) {
	return (1, $l) if ($l eq $dname);
	}
return (1, undef);
}

# type_gandi_create_domain(&account, &domain)
# Actually register a domain, if possible. Returns 0 and an error message if
# it failed, or 1 and an ID for the domain on success.
sub type_gandi_create_domain
{
local ($account, $d) = @_;
local ($server, $sid) = &connect_gandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Get the nameservers
local $nss = &get_domain_nameservers($account, $d);
if (!ref($nss)) {
        return (0, $nss);
        }
elsif (!@$nss) {
        return (0, $text{'rcom_ensrecords'});
        }

# Ensure we have the nameservers?
# XXX
# XXX need at least two?

# Call to create
local $opid;
eval {
	$opid = $server->call("domain_create",
			      $sid,
			      $d->{'dom'},
			      $account->{'gandi_years'} || 1,
			      $account->{'gandi_account'},
			      $account->{'gandi_account'},
			      $account->{'gandi_account'},
			      $account->{'gandi_account'},
			      $nss);
	};
return (0, &text('gandi_error', $@)) if ($@);
return (1, $d->{'dom'});
}

# type_gandi_delete_domain(&account, &domain)
# Deletes a domain previously created with this registrar
sub type_gandi_delete_domain
{
local ($account, $d) = @_;
local ($server, $sid) = &connect_gandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Call to delete
local $opid;
eval {
	$opid = $server->call("domain_del", $sid, $d->{'dom'});
	};
return (0, &text('gandi_error', $@)) if ($@);
return (1, $opid);
}

# type_gandi_get_expiry(&account, &domain)
# Returns either 1 and the expiry time (unix) for a domain, or 0 and an error
# message.
sub type_gandi_get_expiry
{
# XXX
}

# type_gandi_renew_domain(&account, &domain, years)
# Attempts to renew a domain for the specified period. Returns 1 and the
# registrars confirmation code on success, or 0 and an error message on
# failure.
sub type_gandi_renew_domain
{
local ($account, $d, $years) = @_;
local ($server, $sid) = &connect_gandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Call to renew
local $opid;
eval {
	$opid = $server->call("domain_renew", $sid, $d->{'dom'}, $years);
	};
return (0, &text('gandi_error', $@)) if ($@);
return (1, $opid);
}

# type_gandi_add_instructions()
# Returns HTML for instructions to be shown on the account adding form, such
# as where to create one.
sub type_gandi_add_instructions
{
# XXX
return &text('rcom_instructions',
     'https://secure.rconnection.com/sign-up.asp?resell=VIRTUALMIN-TPP');
}

# connect_gandi_api(&account, [return-error])
# Returns a handle connected to the Gandi XML-RPC API and a session ID,
# or calls error
sub connect_gandi_api
{
local ($account, $reterr) = @_;
local $server;
eval {
	$server = Frontier::Client->new('url' => $gandi_api_url,
					'debug' => 0);
	};
if ($@) {
	if ($reterr) {
		return (undef, $@);
		}
	else {
		&error($@);
		}
	}
local $sid;
eval {
	local $safe = $server->boolean(0);
	$sid = $server->call("login", $account->{'gandi_account'},
				      $account->{'gandi_pass'}, $safe);
	};
return $@ =~ /DataError:\s*(.*)/ ? ( undef, $1 ) :
       $@ ? (undef, $@) : ($server, $sid);
}

1;

