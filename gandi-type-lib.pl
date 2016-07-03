# Functions for talking to gandi.net
use strict;
use warnings;
our (%text);
our $module_name;

my $gandi_api_url_test = "https://api.ote.gandi.net/xmlrpc/";
my $gandi_api_url = "https://api.gandi.net/xmlrpc/";

$@ = undef;
eval "use Frontier::Client";
my $frontier_client_err = $@;

# Returns the name of this registrar
sub type_gandi_desc
{
return $text{'type_gandi'};
}

# Returns an error message if needed dependencies are missing
sub type_gandi_check
{
if ($frontier_client_err) {
	my $rv = &text('gandi_eperl', "<tt>Frontier::Client</tt>",
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
	".org", ".pro", ".tel", ".at", ".be", ".cc", ".ch", ".cn", ".co.uk",
	".cz", ".de", ".es", ".eu", ".fm", ".fr", ".in", ".it", ".li", ".lu",
        ".me", ".nu", ".org.uk", ".pl", ".re", ".ru", ".se", ".tv", ".tw",
        ".us");
}

# type_gandi_edit_inputs(&account, new?)
# Returns table fields for entering the account login details
sub type_gandi_edit_inputs
{
my ($account, $new) = @_;
my $rv;
$rv .= &ui_table_row($text{'gandi_account'},
	&ui_textbox("gandi_account", $account->{'gandi_account'}, 30));
$rv .= &ui_table_row($text{'gandi_pass'},
	&ui_textbox("gandi_pass", $account->{'gandi_pass'}, 30));
$rv .= &ui_table_row($text{'rcom_years'},
	&ui_opt_textbox("gandi_years", $account->{'gandi_years'},
			4, $text{'rcom_yearsdef'}));
$rv .= &ui_table_row($text{'rcom_test'},
	&ui_radio("gandi_test", int($account->{'gandi_test'}),
		  [ [ 1, $text{'rcom_test1'} ], [ 0, $text{'rcom_test0'} ] ]));
return $rv;
}

# type_gandi_edit_parse(&account, new?, &in)
# Updates the account object with parsed inputs. Returns undef on success or
# an error message on failure.
sub type_gandi_edit_parse
{
my ($account, $new, $in) = @_;
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
$account->{'gandi_test'} = $in->{'gandi_test'};
return undef;
}

# type_gandi_renew_years(&account, &domain)
# Returns the number of years by default to renew a domain for
sub type_gandi_renew_years
{
my ($account, $d) = @_;
return $account->{'gandi_years'} || 2;
}

# type_gandi_validate(&account)
# Checks if an account's details are vaid. Returns undef if OK or an error
# message if the login or password are wrong.
sub type_gandi_validate
{
my ($account) = @_;
my ($server, $sid) = &connect_gandi_api($account, 1);
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
my ($account, $dname) = @_;
my ($server, $sid) = &connect_gandi_api($account, 1);
return &text('gandi_error', $sid) if (!$server);
my $avail;
eval {
	$avail = $server->call("domain_available", $sid, [ $dname ]);
	};
return &text('gandi_error', "$@") if ($@);
return $avail->{$dname} && $avail->{$dname}->value() ?
	undef : $text{'gandi_taken'};
}

# type_gandi_owned_domain(&account, domain, [id])
# Checks if some domain is owned by the given account. If so, returns the
# 1 and the registrar's ID - if not, returns 1 and undef, on failure returns
# 0 and an error message.
sub type_gandi_owned_domain
{
my ($account, $dname, $id) = @_;
my ($server, $sid) = &connect_gandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Get the domain list
my $list;
eval {
	$list = $server->call("domain_list", $sid);
	};
return (0, &text('gandi_error', "$@")) if ($@);

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
my ($account, $d) = @_;
my ($server, $sid) = &connect_gandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Get the nameservers
my $nss = &get_domain_nameservers($account, $d);
if (!ref($nss)) {
        return (0, $nss);
        }
elsif (!@$nss) {
        return (0, $text{'rcom_ensrecords'});
        }
elsif (@$nss < 2) {
	return (0, &text('gandi_enstwo', 2, $nss->[0]));
	}

# Call to create
my $opid;
eval {
	$opid = $server->call("domain_create",
			      $sid,
			      $d->{'dom'},
			      $d->{'registrar_years'} ||
				$account->{'gandi_years'} || 1,
			      $account->{'gandi_account'},
			      $account->{'gandi_account'},
			      $account->{'gandi_account'},
			      $account->{'gandi_account'},
			      $nss);
	};
return (0, &text('gandi_error', "$@")) if ($@);
return (1, $d->{'dom'});
}

# type_gandi_get_nameservers(&account, &domain)
# Returns a array ref list of nameserver hostnames for some domain, or
# an error message on failure.
sub type_gandi_get_nameservers
{
my ($account, $d) = @_;
my ($server, $sid) = &connect_gandi_api($account, 1);
return &text('gandi_error', $sid) if (!$server);

my $rv;
eval {
	$rv = $server->call("domain_ns_list", $sid, $d->{'dom'});
	$rv = [ map { $_."" } @$rv ];
	};
return $@ ? &text('gandi_error', "$@") : $rv;
}

# type_gandi_set_nameservers(&account, &domain, [&nameservers])
# Updates the nameservers for a domain to match DNS. Returns undef on success
# or an error message on failure.
sub type_gandi_set_nameservers
{
my ($account, $d, $nss) = @_;
my ($server, $sid) = &connect_gandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Get nameservers in DNS
$nss ||= &get_domain_nameservers($account, $d);
if (!ref($nss)) {
	return $nss;
	}
elsif (!@$nss) {
	return $text{'rcom_ensrecords'};
	}
elsif (@$nss < 2) {
	return (0, &text('gandi_enstwo', 2, $nss->[0]));
	}

# Call to set nameservers
eval {
	$server->call("domain_ns_set", $sid, $d->{'dom'}, $nss);
	};
return $@ ? &text('gandi_error', "$@") : undef;
}

# type_gandi_delete_domain(&account, &domain)
# Deletes a domain previously created with this registrar
sub type_gandi_delete_domain
{
my ($account, $d) = @_;
my ($server, $sid) = &connect_gandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Call to delete
my $opid;
eval {
	$opid = $server->call("domain_del", $sid, $d->{'dom'});
	};
return (0, &text('gandi_error', "$@")) if ($@);
return (1, $opid);
}

# type_gandi_get_contact(&account, &domain)
# Returns a array containing hashes of domain contact information, or an error
# message if it could not be found.
sub type_gandi_get_contact
{
my ($account, $d) = @_;
my ($server, $sid) = &connect_gandi_api($account, 1);
return &text('gandi_error', $sid) if (!$server);

# Get the contact IDs and contact details
my $info;
eval {
	$info = $server->call("domain_info", $sid, $d->{'dom'});
	};
return &text('gandi_error', "$@") if ($@);
my @rv;
foreach my $ct ('admin', 'tech', 'billing') {
	next if (!$info->{$ct.'_handle'});
	my $con;
	eval {
		$con = $server->call("contact_info", $sid,
				     $info->{$ct.'_handle'});
		};
	if (!$@ && $con) {
		$con->{'purpose'} = $ct;
		$con->{'handle'} ||= $info->{$ct.'_handle'};
		$con->{'name'} = $con->{'company_name'} ||
				 $con->{'association_name'} ||
			         $con->{'body_name'};
		push(@rv, $con);
		}
	}

return \@rv;
}

# type_gandi_save_contact(&&account, &domain, &contacts)
# Updates contacts from an array of hashes
sub type_gandi_save_contact
{
my ($account, $d, $cons) = @_;

my ($server, $sid) = &connect_gandi_api($account, 1);
return &text('gandi_error', $sid) if (!$server);

# Get existing contacts
my $oldcons = &type_gandi_get_contact($account, $d);
return $oldcons if (!ref($oldcons));

# For changed contacts, create a new one and associate with the domain
my %same;
foreach my $c (@$cons) {
	my ($oldc) = grep { $_->{'purpose'} eq $c->{'purpose'} } @$oldcons;
	my $hash = &contact_hash_to_string($c);
	if ($oldc && $hash eq &contact_hash_to_string($oldc)) {
		# No change
		next;
		}
	eval {
		# Make the new contact
		if ($same{$hash}) {
			# Re-use same details
			$c->{'handle'} = $same{$hash};
			}
		else {
			# Keep all original extra parameters the same
			my %params;
			my @skip = ( 'id', 'type', 'purpose', 'handle', 'name', 'class', 'firstname', 'lastname', 'address', 'zipcode', 'city', 'country', 'phone', 'email' );
			foreach my $k (keys %$c) {
				if (&indexof($k, @skip) < 0 &&
				    $c->{$k}) {
					$params{$k} = $c->{$k};
					}
				}
			# Convert name param into appropriate for class
			if ($c->{'name'}) {
				if ($c->{'class'} eq 'individual') {
					die $text{'gandi_eindivname'};
					}
				$params{$c->{'class'}.'_name'} = $c->{'name'};
				}
			$c->{'handle'} = $server->call("contact_create", $sid,
					$c->{'class'},
					$c->{'firstname'},
					$c->{'lastname'},
					$c->{'address'},
					$server->string($c->{'zipcode'}),
					$c->{'city'},
					$c->{'country'},
					$server->string($c->{'phone'}),
					$c->{'email'},
					\%params);
			$same{$hash} = $c->{'handle'};
			}

		# Update in the domain
		if ($c->{'purpose'} eq 'owner') {
			$server->call("domain_change_owner", $sid,
				$d->{'dom'}, $c->{'handle'});
			}
		else {
			$server->call("domain_change_contact", $sid,
				$d->{'dom'}, $c->{'purpose'}, $c->{'handle'});
			}
		};
	return &text('gandi_error', "$@") if ($@);
	}
return undef;
}

# type_gandi_get_contact_schema(&account, &domain, type)
# Returns a list of fields for domain contacts, as seen by gandi.net
sub type_gandi_get_contact_schema
{
my ($account, $d, $type) = @_;
return ( { 'name' => 'handle',
	   'readonly' => 1 },
         { 'name' => 'class',
	   'choices' => [ [ 'individual', $text{'gandi_individual'} ],
			  [ 'company', $text{'gandi_company'} ],
			  [ 'public', $text{'gandi_public'} ],
			  [ 'association', $text{'gandi_association'} ] ],
	   'opt' => 0,
	 },
	 { 'name' => 'name',
	   'size' => 60,
	   'opt' => 1 },
	 { 'name' => 'firstname',
	   'size' => 40,
	   'opt' => 0 },
	 { 'name' => 'lastname',
	   'size' => 40,
	   'opt' => 0 },
	 { 'name' => 'address',
	   'size' => 60,
	   'opt' => 0 },
	 { 'name' => 'city',
	   'size' => 40,
	   'opt' => 0 },
	 { 'name' => 'state',
	   'size' => 40,
	   'opt' => 1 },
         { 'name' => 'zipcode',
	   'size' => 20,
	   'opt' => 1 },
         { 'name' => 'country',
	   'choices' => [ map { [ $_->[1], $_->[0] ] } &list_countries() ],
	   'opt' => 1 },
         { 'name' => 'email',
	   'size' => 60,
	   'opt' => 0 },
         { 'name' => 'phone',
	   'size' => 40,
	   'opt' => 0 },
	);
}

# type_gandi_get_expiry(&account, &domain)
# Returns either 1 and the expiry time (unix) for a domain, or 0 and an error
# message.
sub type_gandi_get_expiry
{
my ($account, $d) = @_;
my ($server, $sid) = &connect_gandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Call to get info
my $info;
eval {
	$info = $server->call("domain_info", $sid, $d->{'dom'});
	};
return (0, &text('gandi_error', "$@")) if ($@);
my $expirydate = $info->{'registry_expiration_date'}->value();
if ($expirydate =~ /^(\d{4})(\d\d)(\d\d)T(\d\d):(\d\d):(\d\d)$/) {
	return (1, timelocal($6, $5, $4, $3, $2-1, $1-1900));
	}
return (0, &text('gandi_eexpiry', $expirydate));
}

# type_gandi_renew_domain(&account, &domain, years)
# Attempts to renew a domain for the specified period. Returns 1 and the
# registrars confirmation code on success, or 0 and an error message on
# failure.
sub type_gandi_renew_domain
{
my ($account, $d, $years) = @_;
my ($server, $sid) = &connect_gandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Call to renew
my $opid;
eval {
	$opid = $server->call("domain_renew", $sid, $d->{'dom'}, $years);
	};
return (0, &text('gandi_error', "$@")) if ($@);
return (1, $opid);
}

# type_gandi_add_instructions()
# Returns HTML for instructions to be shown on the account adding form, such
# as where to create one.
sub type_gandi_add_instructions
{
return &text('gandi_instructions', 'https://www.gandi.net/resellers/');
}

# type_gandi_transfer_domain(&account, &domain, key)
# Transfer a domain from whatever registrar it is currently hosted with to
# this Gandi account. Returns 1 and an order ID on succes, or 0
# and an error mesasge on failure. If a number of years is given, also renews
# the domain for that period.
sub type_gandi_transfer_domain
{
my ($account, $d, $key) = @_;

my ($server, $sid) = &connect_gandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Get my nameservers
my $nss = &get_domain_nameservers($account, $d);
if (!ref($nss)) {
        return (0, $nss);
        }
elsif (!@$nss) {
        return (0, $text{'rcom_ensrecords'});
        }
elsif (@$nss < 2) {
	return (0, &text('gandi_enstwo', 2, $nss->[0]));
	}

# Do the transfer
my $tid;
eval {
	$tid = $server->call("domain_transfer_in", $sid, $d->{'dom'},
		$account->{'gandi_account'},
		$account->{'gandi_account'},
		$account->{'gandi_account'},
		$account->{'gandi_account'},
		$nss,
		$key);
	};
return (0, &text('gandi_error', "$@")) if ($@);
return (1, $tid);
}

# connect_gandi_api(&account, [return-error])
# Returns a handle connected to the Gandi XML-RPC API and a session ID,
# or calls error
sub connect_gandi_api
{
my ($account, $reterr) = @_;
my $server;
eval {
	$server = Frontier::Client->new(
		'url' => $account->{'gandi_test'} ? $gandi_api_url_test
					          : $gandi_api_url,
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
my $sid;
eval {
	my $safe = $server->boolean(0);
	$sid = $server->call("login", $account->{'gandi_account'},
				      $account->{'gandi_pass'}, $safe);
	};
return $@ =~ /DataError:\s*(.*)/ ? ( undef, $1 ) :
       $@ ? (undef, $@) : ($server, $sid);
}

1;
