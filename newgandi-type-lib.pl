# Functions for talking to gandi.net with the new API

$gandi_api_url_test = "https://rpc.ote.gandi.net/xmlrpc/";
$gandi_api_url = "https://rpc.gandi.net/xmlrpc/";

$@ = undef;
eval "use Frontier::Client";
$frontier_client_err = $@;

# Returns the name of this registrar
sub type_newgandi_desc
{
return $text{'type_newgandi'};
}

# Returns an error message if needed dependencies are missing
sub type_newgandi_check
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

# type_newgandi_domains(&account)
# Returns a list of TLDs that can be used with gandi.net.
sub type_newgandi_domains
{
local ($account) = @_;
if ($account) {
	# Try to query gandi API
	local ($server, $sid) = &connect_newgandi_api($account, 1);
	if ($server) {
		local $doms;
		eval {
			$doms = $server->call("domain.tld.list", $sid);
			};
		if ($doms && !$@) {
			return map { ".".$_->{'name'} } @$doms;
			}
		}
	}
# Fall back to hard-coded list
return (
	".ae.org", ".aero", ".af", ".ag", ".ar.com", ".asia", ".at", ".be",
	".biz", ".br.com", ".bz", ".ca", ".cc", ".ch", ".cn", ".cn.com",
	".co", ".co.uk", ".com", ".com.de", ".coop", ".cx", ".de", ".de.com",
	".es", ".eu", ".eu.com", ".fm", ".fr", ".gb.com", ".gb.net", ".gr.com",
	".gs", ".gy", ".hk", ".hn", ".ht", ".hu.com", ".im", ".info",
	".it", ".jp", ".jpn.com", ".ki", ".kr.com", ".la", ".lc", ".li",
	".lt", ".lu", ".me", ".me.uk", ".mn", ".mobi", ".mu", ".name",
	".net", ".nf", ".nl", ".no", ".no.com", ".nu", ".org", ".org.uk",
	".pl", ".pro", ".pt", ".qc.com", ".re", ".ru", ".ru.com", ".sa.com",
	".sb", ".sc", ".se", ".se.com", ".se.net", ".tel", ".tl", ".travel",
	".tv", ".tw", ".uk.com", ".uk.net", ".us", ".us.com", ".us.org",
	".uy.com", ".vc", ".ws", ".xn--p1ai", ".za.com",
	);
}

# type_newgandi_edit_inputs(&account, new?)
# Returns table fields for entering the account login details
sub type_newgandi_edit_inputs
{
local ($account, $new) = @_;
local $rv;
$rv .= &ui_table_row($text{'gandi_contact'},
	&ui_textbox("gandi_account", $account->{'gandi_account'}, 30));
$rv .= &ui_table_row($text{'gandi_apikey'},
	&ui_textbox("gandi_apikey", $account->{'gandi_apikey'}, 30));
$rv .= &ui_table_row($text{'rcom_years'},
	&ui_opt_textbox("gandi_years", $account->{'gandi_years'},
			4, $text{'rcom_yearsdef'}));
$rv .= &ui_table_row($text{'rcom_test'},
	&ui_radio("gandi_test", int($account->{'gandi_test'}),
		  [ [ 1, $text{'rcom_test1'} ], [ 0, $text{'rcom_test0'} ] ]));
return $rv;
}

# type_newgandi_edit_parse(&account, new?, &in)
# Updates the account object with parsed inputs. Returns undef on success or
# an error message on failure.
sub type_newgandi_edit_parse
{
local ($account, $new, $in) = @_;
$in->{'gandi_account'} =~ /^\S+$/ || return $text{'gandi_eaccount'};
$account->{'gandi_account'} = $in->{'gandi_account'};
$in->{'gandi_apikey'} =~ /^\S+$/ || return $text{'gandi_eapikey'};
$account->{'gandi_apikey'} = $in->{'gandi_apikey'};
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

# type_newgandi_renew_years(&account, &domain)
# Returns the number of years by default to renew a domain for
sub type_newgandi_renew_years
{
local ($account, $d) = @_;
return $account->{'gandi_years'} || 2;
}

# type_newgandi_validate(&account)
# Checks if an account's details are vaid. Returns undef if OK or an error
# message if the login or password are wrong.
sub type_newgandi_validate
{
local ($account) = @_;
local ($server, $sid_or_err) = &connect_newgandi_api($account, 1);
if ($server) {
	return undef;
	}
else {
	return $sid_or_err;
	}
}

# type_newgandi_check_domain(&account, domain)
# Checks if some domain name is available for registration, returns undef if
# yes, or an error message if not.
sub type_newgandi_check_domain
{
local ($account, $dname) = @_;
local ($server, $sid) = &connect_newgandi_api($account, 1);
return &text('gandi_error', $sid) if (!$server);
while(1) {
	local $avail;
	eval {
		$avail = $server->call("domain.available", $sid, [ $dname ]);
		};
	return &text('gandi_error', "$@") if ($@);
	next if ($avail->{$dname} eq 'pending');
	return undef if ($avail->{$dname} eq 'available');
	return $text{'gandi_taken'};
	}
}

# type_newgandi_owned_domain(&account, domain, [id])
# Checks if some domain is owned by the given account. If so, returns the
# 1 and the registrar's ID - if not, returns 1 and undef, on failure returns
# 0 and an error message.
sub type_newgandi_owned_domain
{
local ($account, $dname, $id) = @_;
local ($server, $sid) = &connect_newgandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Get the domain list
local $list;
eval {
	$list = $server->call("domain.list", $sid);
	};
return (0, &text('gandi_error', "$@")) if ($@);

# Check if on list
foreach my $l (@$list) {
	return (1, $l) if ($l eq $dname);
	}
return (1, undef);
}

# type_newgandi_create_domain(&account, &domain)
# Actually register a domain, if possible. Returns 0 and an error message if
# it failed, or 1 and an ID for the domain on success.
sub type_newgandi_create_domain
{
local ($account, $d) = @_;
local ($server, $sid) = &connect_newgandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Get the nameservers
local $nss = &get_domain_nameservers($account, $d);
if (!ref($nss)) {
        return (0, $nss);
        }
elsif (!@$nss) {
        return (0, $text{'rcom_ensrecords'});
        }
elsif (@$nss < 2) {
	return (0, &text('gandi_enstwo', 2, $nss->[0]));
	}
print STDERR "nss=",join(" ", @$nss),"\n";

# Check if the contact can be used
# Doesn't seem to have any value
#eval {
#	local $assoc = $server->call("contact.can_associate_domain",
#				     $sid,
#				     $account->{'gandi_account'},
#				     { 'domain' => $d->{'dom'},
#				       'owner' => $server->boolean(1),
#				       'admin' => $server->boolean(1) });
#	use Data::Dumper;
#	print STDERR Dumper($assoc);
#	$assoc || return (0, &text('gandi_eassoc',
#				   $account->{'gandi_account'}));
#	};
#return (0, &text('gandi_error', "$@")) if ($@);

# Call to create
local $oper;
eval {
	$oper = $server->call("domain.create",
			      $sid,
			      $d->{'dom'},
			      { 'duration' => 
				      $d->{'registrar_years'} ||
					$account->{'gandi_years'} || 1,
				'owner' => $account->{'gandi_account'},
				'admin' => $account->{'gandi_account'},
				'bill' => $account->{'gandi_account'},
				'tech' => $account->{'gandi_account'},
			        'nameservers' => $nss });
	};
return (0, &text('gandi_error', "$@")) if ($@);

# Wait for completion
local $tries = 0;
while(1) {
	sleep(1);
	local $rv = $server->call("operation.info", $sid, $oper->{'id'});
	use Data::Dumper;
	print STDERR Dumper($rv);
	if ($rv->{'step'} eq 'DONE') {
		last;
		}
	elsif ($rv->{'step'} eq 'ERROR') {
		return (0, &text('gandi_ecreate', $rv->{'last_error'}));
		}
	$tries++;
	if ($tries > 30) {
		return (0, &text('gandi_etries', $rv->{'step'}, 30));
		}
	}

return (1, $d->{'dom'});
}

# type_newgandi_get_nameservers(&account, &domain)
# Returns a array ref list of nameserver hostnames for some domain, or
# an error message on failure.
sub type_newgandi_get_nameservers
{
local ($account, $d) = @_;
local ($server, $sid) = &connect_newgandi_api($account, 1);
return &text('gandi_error', $sid) if (!$server);

local $rv;
eval {
	$rv = $server->call("domain.ns.list", $sid, $d->{'dom'});
	$rv = [ map { $_."" } @$rv ];
	};
return $@ ? &text('gandi_error', "$@") : $rv;
}

# type_newgandi_set_nameservers(&account, &domain, [&nameservers])
# Updates the nameservers for a domain to match DNS. Returns undef on success
# or an error message on failure.
sub type_newgandi_set_nameservers
{
local ($account, $d, $nss) = @_;
local ($server, $sid) = &connect_newgandi_api($account, 1);
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
	$server->call("domain.ns.set", $sid, $d->{'dom'}, $nss);
	};
return $@ ? &text('gandi_error', "$@") : undef;
}

# type_newgandi_delete_domain(&account, &domain)
# Deletes a domain previously created with this registrar
sub type_newgandi_delete_domain
{
local ($account, $d) = @_;
local ($server, $sid) = &connect_newgandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Call to delete
local $opid;
eval {
	$opid = $server->call("domain.delete", $sid, $d->{'dom'});
	};
return (0, &text('gandi_error', "$@")) if ($@);
return (1, $opid);
}

# type_newgandi_get_contact(&account, &domain)
# Returns a array containing hashes of domain contact information, or an error
# message if it could not be found.
sub type_newgandi_get_contact
{
local ($account, $d) = @_;
local ($server, $sid) = &connect_newgandi_api($account, 1);
return &text('gandi_error', $sid) if (!$server);

# Get the contact IDs and contact details
local $info;
eval {
	$info = $server->call("domain.info", $sid, $d->{'dom'});
	};
return &text('gandi_error', "$@") if ($@);
local @rv;
foreach my $ct ('admin', 'tech', 'billing') {
	next if (!$info->{$ct.'_handle'});
	local $con;
	eval {
		$con = $server->call("contact.info", $sid,
				     $info->{$ct.'_handle'});
		};
	if (!$@ && $con) {
		$con->{'type'} = $ct;
		$con->{'handle'} ||= $info->{$ct.'_handle'};
		$con->{'name'} = $con->{'company_name'} ||
				 $con->{'association_name'} ||
			         $con->{'body_name'};
		push(@rv, $con);
		}
	}

return \@rv;
}

# type_newgandi_save_contact(&&account, &domain, &contacts)
# Updates contacts from an array of hashes
sub type_newgandi_save_contact
{
local ($account, $d, $cons) = @_;

local ($server, $sid) = &connect_newgandi_api($account, 1);
return &text('gandi_error', $sid) if (!$server);

# Get existing contacts
local $oldcons = &type_newgandi_get_contact($account, $d);
return $oldcons if (!ref($oldcons));

# For changed contacts, create a new one and associate with the domain
foreach my $c (@$cons) {
	local ($oldc) = grep { $_->{'type'} eq $c->{'type'} } @$oldcons;
	local $hash = &contact_hash_to_string($c);
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
			local %params;
			local @skip = ( 'id', 'type', 'handle', 'name', 'class', 'firstname', 'lastname', 'address', 'zipcode', 'city', 'country', 'phone', 'email' );
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
			$c->{'handle'} = $server->call("contact.create", $sid,
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
		if ($c->{'type'} eq 'owner') {
			$server->call("domain.change.owner", $sid,
				$d->{'dom'}, $c->{'handle'});
			}
		else {
			$server->call("domain.change.contact", $sid,
				$d->{'dom'}, $c->{'type'}, $c->{'handle'});
			}
		};
	return &text('gandi_error', "$@") if ($@);
	}
return undef;
}

# type_newgandi_get_contact_schema(&account, &domain, type, new?, class)
# Returns a list of fields for domain contacts, as seen by gandi.net
sub type_newgandi_get_contact_schema
{
local ($account, $d, $type, $newcontact, $cls) = @_;
return ( { 'name' => 'handle',
	   'readonly' => 1 },
         { 'name' => 'type',
	   'choices' => [ [ 0, $text{'gandi_individual'} ],
			  [ 1, $text{'gandi_company'} ],
			  [ 2, $text{'gandi_public'} ],
			  [ 3, $text{'gandi_association'} ] ],
	   'opt' => 0,
	   'readonly' => 1,
	 },
	 { 'name' => 'given',
	   'size' => 40,
	   'opt' => 0 },
	 { 'name' => 'family',
	   'size' => 40,
	   'opt' => 0 },
	 $cls == 1 || $cls == 2 || $cls == 3 ? (
		 { 'name' => 'orgname',
		   'size' => 40,
		   'opt' => 0,
		   'readonly' => !$newcontact },
		 ) :
		 ( ),
	 { 'name' => 'streetaddr',
	   'size' => 60,
	   'opt' => 0 },
	 { 'name' => 'city',
	   'size' => 40,
	   'opt' => 0 },
	 { 'name' => 'state',
	   'size' => 40,
	   'opt' => 1 },
         { 'name' => 'zip',
	   'size' => 10,
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
	 $newcontact ? ( { 'name' => 'password',
		           'size' => 40,
		           'opt' => 0 } )
		     : ( ),
	);
}

# type_newgandi_get_contact_classes(&account)
# Returns a list of hash refs with ID and desc fields, for different classes
# of contacts (individual, business, etc)
sub type_newgandi_get_contact_classes
{
my ($account) = @_;
return ( { 'id' => 0, 'desc' => $text{'gandi_individual'},
	   'field' => 'type' },
	 { 'id' => 1, 'desc' => $text{'gandi_company'},
	   'field' => 'type' },
	 { 'id' => 2, 'desc' => $text{'gandi_public'},
	   'field' => 'type' },
	 { 'id' => 3, 'desc' => $text{'gandi_association'},
	   'field' => 'type' } );
}

# type_newgandi_list_contacts(&account)
# Returns a list of all contacts associated with some Gandi account
sub type_newgandi_list_contacts
{
local ($account) = @_;
local ($server, $sid) = &connect_newgandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);
local $list;
eval {
	$list = $server->call("contact.list", $sid);
	};
return (0, &text('gandi_error', "$@")) if ($@);
foreach my $con (@$list) {
	$con->{'name'} = $con->{'company_name'} ||
                         $con->{'association_name'} ||
                         $con->{'body_name'};
	$con->{'id'} = $con->{'handle'};
	}
return (1, $list);
}

# type_newgandi_create_one_contact(&account, &contact)
# Create a single new contact for some account
sub type_newgandi_create_one_contact
{
local ($account, $con) = @_;
local ($server, $sid) = &connect_newgandi_api($account, 1);
return &text('gandi_error', $sid) if (!$server);

eval {
	local $callcon = { %$con };
	foreach my $k (keys %$callcon) {
		delete($callcon->{$k}) if ($callcon->{$k} eq '');
		}
	$callcon->{'zip'} = $server->string($con->{'zip'});
	$callcon->{'phone'} = $server->string($con->{'phone'});
	local $newcon = $server->call("contact.create", $sid, $callcon);
	$con->{'id'} = $con->{'handle'} = $newcon->{'handle'};
	};
return (0, &text('gandi_error', "$@")) if ($@);

return undef;
}

# type_newgandi_modify_one_contact(&account, &contact)
# Update a single contact for some account. Doesn't send fields not in the
# schema, so they are left unchanged.
sub type_newgandi_modify_one_contact
{
local ($account, $con) = @_;
local ($server, $sid) = &connect_newgandi_api($account, 1);
return &text('gandi_error', $sid) if (!$server);

eval {
	local $callcon = { %$con };
	local @schema = &type_newgandi_get_contact_schema(
				$account, undef, undef, 0, $con->{'type'});
	foreach my $k (keys %$callcon) {
		delete($callcon->{$k}) if ($callcon->{$k} eq '');
		local ($s) = grep { $_->{'name'} eq $k } @schema;
		delete($callcon->{$k}) if (!$s || $s->{'readonly'});
		}
	$callcon->{'zip'} = $server->string($con->{'zip'});
	$callcon->{'phone'} = $server->string($con->{'phone'});
	use Data::Dumper;
	print STDERR Dumper($callcon);
	$server->call("contact.update", $sid, $con->{'handle'}, $callcon);
	};
return (0, &text('gandi_error', "$@")) if ($@);

return undef;
}

# type_newgandi_get_expiry(&account, &domain)
# Returns either 1 and the expiry time (unix) for a domain, or 0 and an error
# message.
sub type_newgandi_get_expiry
{
local ($account, $d) = @_;
local ($server, $sid) = &connect_newgandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Call to get info
local $info;
eval {
	$info = $server->call("domain.info", $sid, $d->{'dom'});
	};
use Data::Dumper;
print STDERR "err=$@\n";
print STDERR Dumper($info);
return (0, &text('gandi_error', "$@")) if ($@);
local $expirydate = $info->{'registry_expiration_date'};
if ($expirydate =~ /^(\d{4})(\d\d)(\d\d)T(\d\d):(\d\d):(\d\d)$/) {
	return (1, timelocal($6, $5, $4, $3, $2-1, $1-1900));
	}
return (0, &text('gandi_eexpiry', $expirydate));
}

# type_newgandi_renew_domain(&account, &domain, years)
# Attempts to renew a domain for the specified period. Returns 1 and the
# registrars confirmation code on success, or 0 and an error message on
# failure.
sub type_newgandi_renew_domain
{
local ($account, $d, $years) = @_;
local ($server, $sid) = &connect_newgandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Call to renew
local $opid;
eval {
	$opid = $server->call("domain.renew", $sid, $d->{'dom'}, $years);
	};
return (0, &text('gandi_error', "$@")) if ($@);
return (1, $opid);
}

# type_newgandi_add_instructions()
# Returns HTML for instructions to be shown on the account adding form, such
# as where to create one.
sub type_newgandi_add_instructions
{
return &text('gandi_newinstructions', 'https://www.gandi.net/resellers/',
				      'https://www.gandi.net/admin/apixml');
}

# type_newgandi_transfer_domain(&account, &domain, key)
# Transfer a domain from whatever registrar it is currently hosted with to
# this Gandi account. Returns 1 and an order ID on succes, or 0
# and an error mesasge on failure. If a number of years is given, also renews
# the domain for that period.
sub type_newgandi_transfer_domain
{
local ($account, $d, $key) = @_;

local ($server, $sid) = &connect_newgandi_api($account, 1);
return (0, &text('gandi_error', $sid)) if (!$server);

# Get my nameservers
local $nss = &get_domain_nameservers($account, $d);
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
local $tid;
eval {
	$tid = $server->call("domain.transfer.in", $sid, $d->{'dom'},
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

# connect_newgandi_api(&account, [return-error])
# Returns a handle connected to the Gandi XML-RPC API and a session ID,
# or calls error
sub connect_newgandi_api
{
local ($account, $reterr) = @_;
local $server;
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
local $ver;
eval {
	$ver = $server->call("version.info", $account->{'gandi_apikey'});
	};
return $@ =~ /DataError:\s*(.*)/ ? ( undef, $1 ) :
       $@ ? (undef, $@) :
       !$ver ? (undef, "No version returned")
	     : ($server, $account->{'gandi_apikey'});
}

1;

