# Functions for talking to namecheap
use strict;
no strict 'refs';
use warnings;
our (%text);
our $module_name;

my $namecheap_api_url_test = "https://api.sandbox.namecheap.com/xml.response";
my $namecheap_api_url = "https://api.namecheap.com/xml.response";

$@ = undef;
eval "use XML::Simple";
my $xml_simple_err = $@;

# Returns the name of this registrar
sub type_namecheap_desc
{
return $text{'type_namecheap'};
}

# Returns an error message if needed dependencies are missing
sub type_namecheap_check
{
if ($xml_simple_err) {
	my $rv = &text('namecheap_eperl', "<tt>XML::Simple</tt>",
		     "<tt>".&html_escape($xml_simple_err)."</tt>");
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
my ($account) = @_;
if ($account) {
	my ($ok, $xml) = &call_namecheap_api(
				$account, "namecheap.domains.getTldList");
	if ($ok) {
		return map { ".".$_->{'Name'} } @{$xml->{'Tlds'}->{'Tld'}};
		}
	}
return ( ".accountant", ".adult", ".ae.org", ".africa", ".airforce", ".apartments", ".attorney", ".auction", ".berlin", ".bingo", ".blackfriday", ".boo", ".boston", ".bot", ".br.com", ".build", ".builders", ".business", ".bz", ".cab", ".camera", ".camp", ".cards", ".casa", ".catering", ".ceo", ".ch", ".christmas", ".cleaning", ".clothing", ".cm", ".cn", ".cn.com", ".co.bz", ".co.com", ".co.in", ".com.au", ".com.cn", ".com.co", ".com.de", ".com.es", ".com.mx", ".com.pe", ".com.se", ".com.sg", ".com.vc", ".community", ".company", ".condos", ".construction", ".contact", ".contractors", ".cooking", ".country", ".courses", ".creditcard", ".cricket", ".cruises", ".cx", ".cymru", ".dad", ".day", ".de", ".de.com", ".deals", ".degree", ".democrat", ".dental", ".dentist", ".desi", ".diamonds", ".discount", ".domains", ".earth", ".eco", ".education", ".engineer", ".equipment", ".es", ".esq", ".eu.com", ".exposed", ".fail", ".family", ".fan", ".fans", ".fashion", ".feedback", ".film", ".fish", ".fishing", ".flap", ".florist", ".foo", ".football", ".fr", ".furniture", ".futbol", ".fyi", ".gallery", ".garden", ".gay", ".gb.net", ".gdn", ".gift", ".gifts", ".glass", ".gmbh", ".gr.com", ".graphics", ".gratis", ".gripe", ".group", ".guide", ".hamburg", ".healthcare", ".hiphop", ".hockey", ".holdings", ".holiday", ".horse", ".hospital", ".how", ".hu.net", ".id", ".immo", ".immobilien", ".in", ".in.net", ".industries", ".ing", ".insure", ".is", ".jetzt", ".jewelry", ".jp.net", ".jpn.com", ".juegos", ".kaufen", ".kids", ".kiwi", ".krd", ".kyoto", ".la", ".law", ".lawyer", ".lease", ".legal", ".li", ".lighting", ".limited", ".limo", ".london", ".ltda", ".luxury", ".maison", ".management", ".market", ".meme", ".memorial", ".menu", ".mex.com", ".miami", ".moda", ".moe", ".mortgage", ".mov", ".mx", ".nagoya", ".name", ".navy", ".net.au", ".net.cn", ".net.pe", ".net.vc", ".new", ".nexus", ".ngo", ".nl", ".nom.es", ".nu", ".nyc", ".observer", ".okinawa", ".ong", ".onl", ".org.au", ".org.cn", ".org.es", ".org.mx", ".org.pe", ".org.uk", ".org.vc", ".osaka", ".page", ".paris", ".pe", ".phd", ".photo", ".pictures", ".place", ".plumbing", ".porn", ".prodazha", ".prof", ".pub", ".realty", ".rehab", ".reise", ".reisen", ".republican", ".reviews", ".rip", ".rsvp", ".ru.com", ".ryukyu", ".sa.com", ".salon", ".sarl", ".sats", ".school", ".schule", ".se.net", ".sex", ".sexy", ".sg", ".shopping", ".ski", ".so", ".soccer", ".solar", ".soy", ".study", ".substack", ".sucks", ".supplies", ".supply", ".supreme", ".surf", ".surgery", ".tattoo", ".tel", ".tennis", ".theater", ".tienda", ".tires", ".tokyo", ".trading", ".tv", ".u2", ".uk.com", ".uk.net", ".university", ".us.com", ".us.org", ".vacations", ".vc", ".vet", ".viajes", ".video", ".villas", ".vision", ".vodka", ".voice", ".voting", ".voyage", ".w3n", ".wales", ".wedding", ".xn--3ds443g", ".xn--6frz82g", ".xxx", ".yokohama", ".za.com", ".zip" );
}

# type_namecheap_edit_inputs(&account, new?)
# Returns table fields for entering the account login details
sub type_namecheap_edit_inputs
{
my ($account, $new) = @_;
my $rv;

$rv .= &ui_table_row($text{'namecheap_user'},
	&ui_textbox("namecheap_user", $account->{'namecheap_user'}, 30));

$rv .= &ui_table_row($text{'namecheap_apikey'},
	&ui_textbox("namecheap_apikey", $account->{'namecheap_apikey'}, 40));

$rv .= &ui_table_row($text{'namecheap_srcdom'},
	&ui_opt_textbox("namecheap_srcdom", $account->{'namecheap_srcdom'}, 30,
			$text{'namecheap_srcdom_def'}));

$rv .= &ui_table_row($text{'rcom_years'},
	&ui_opt_textbox("namecheap_years", $account->{'namecheap_years'},
			4, $text{'rcom_yearsdef'}));

$rv .= &ui_table_row($text{'namecheap_ip'},
	&ui_opt_textbox("namecheap_ip", $account->{'namecheap_ip'},
			20, $text{'namecheap_ipdef'}));

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
my ($account, $new, $in) = @_;
$in->{'namecheap_user'} =~ /^\S+$/ || return $text{'namecheap_euser'};
$account->{'namecheap_user'} = $in->{'namecheap_user'};
$in->{'namecheap_apikey'} =~ /^\S+$/ || return $text{'namecheap_eapikey'};
$account->{'namecheap_apikey'} = $in->{'namecheap_apikey'};
if ($in->{'namecheap_srcdom_def'}) {
	delete($account->{'namecheap_srcdom'});
	}
else {
	$in->{'namecheap_srcdom'} =~ /^\S+$/ || return $text{'namecheap_esrcdom'};
	$account->{'namecheap_srcdom'} = $in->{'namecheap_srcdom'};
	}
if ($in->{'namecheap_years_def'}) {
	delete($account->{'namecheap_years'});
	}
else {
	$in->{'namecheap_years'} =~ /^\d+$/ && $in->{'namecheap_years'} > 0 &&
	  $in->{'namecheap_years'} <= 10 || return $text{'rcom_eyears'};
	$account->{'namecheap_years'} = $in->{'namecheap_years'};
	}
if ($in->{'namecheap_ip_def'}) {
	delete($account->{'namecheap_ip'});
	}
else {
	&check_ipaddress($in->{'namecheap_ip'}) ||
		return $text{'namecheap_eip'};
	$account->{'namecheap_ip'} = $in->{'namecheap_ip'};
	}
$account->{'namecheap_test'} = $in->{'namecheap_test'};
return undef;
}

# type_namecheap_renew_years(&account, &domain)
# Returns the number of years by default to renew a domain for
sub type_namecheap_renew_years
{
my ($account, $d) = @_;
return $account->{'namecheap_years'} || 2;
}

# type_namecheap_validate(&account)
# Checks if an account's details are vaid. Returns undef if OK or an error
# message if the login or password are wrong.
sub type_namecheap_validate
{
my ($account) = @_;
my ($ok, $xml) = &call_namecheap_api($account,
			"namecheap.domains.getList");
if ($ok) {
	# Connected OK .. but does the source domain exist?
	if (!$account->{'namecheap_srcdom'}) {
		return undef;
		}
	my ($ok, $xml) = &call_namecheap_api($account,
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
my ($account, $dname) = @_;
my ($ok, $xml) = &call_namecheap_api($account, "namecheap.domains.check",
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

# type_namecheap_owned_domain(&account, domain)
# Checks if some domain is owned by the given account. If so, returns the
# 1 and the registrar's ID - if not, returns 1 and undef, on failure returns
# 0 and an error message.
sub type_namecheap_owned_domain
{
my ($account, $dname) = @_;
my ($ok, $xml) = &call_namecheap_api($account, "namecheap.domains.getinfo",
					{ 'DomainName' => $dname });
if (!$ok && $xml =~ /Domain Name not found/i) {
	return (1, undef);
	}
elsif (!$ok) {
	return (0, &text('namecheap_error', $xml));
	}
else {
	return (1, $xml->{'DomainGetInfoResult'}->{'ID'});
	}
}

# type_namecheap_create_domain(&account, &domain)
# Actually register a domain, if possible. Returns 0 and an error message if
# it failed, or 1 and an ID for the domain on success.
sub type_namecheap_create_domain
{
my ($account, $d) = @_;

# Get the nameservers
my $nss = &get_domain_nameservers($account, $d);
if (!ref($nss)) {
        return (0, $nss);
        }
elsif (!@$nss) {
        return (0, $text{'rcom_ensrecords'});
        }
elsif (@$nss < 2) {
	return (0, &text('namecheap_enstwo', 2, $nss->[0]));
	}

# Get the domain to copy contacts from, if we need it
my $srcxml;
if ($account->{'namecheap_srcdom'}) {
	my ($ok, $xml) = &call_namecheap_api($account,
			"namecheap.domains.getContacts",
			{ 'DomainName' => $account->{'namecheap_srcdom'} });
	$ok || return (0, &text('namecheap_error', $xml));
	$srcxml = $xml;
	}

# Build list of params
my %params = ( 'DomainName' => $d->{'dom'},
	       'Years' => $d->{'registrar_years'} ||
                          $account->{'namecheap_years'} || 1,
	     );
if (!$d->{'dns_cloud'} || $d->{'dns_cloud'} ne 'namecheap') {
	# Don't set nameservers if we're going to use namecheap for hosting
	# DNS for this domain
	$params{'Nameservers'} = join(",", @$nss);
	}
if ($srcxml) {
	foreach my $t (keys %{$srcxml->{'DomainContactsResult'}}) {
		my $con = $srcxml->{'DomainContactsResult'}->{$t};
		next if (!$con->{'FirstName'});
		foreach my $ck (keys %$con) {
			$params{$t.$ck} = $con->{$ck};
			}
		}
	}

# Call to create
my ($ok, $xml) = &call_namecheap_api($account,
	"namecheap.domains.create", \%params);
return (0, &text('namecheap_error', $xml)) if (!$ok);

return (1, $xml->{'DomainCreateResult'}->{'DomainID'});
}

# type_namecheap_get_nameservers(&account, &domain)
# Returns a array ref list of nameserver hostnames for some domain, or
# an error message on failure.
sub type_namecheap_get_nameservers
{
my ($account, $d) = @_;
$d->{'dom'} =~ /^([^\.]+)\.(\S+)$/ || return "Invalid domain name $d->{'dom'}";
my ($sld, $tld) = ($1, $2);
my ($ok, $xml) = &call_namecheap_api($account,
	"namecheap.domains.dns.getList",
	{ 'SLD' => $sld, 'TLD' => $tld });
return &text('namecheap_error', $xml) if (!$ok);
my $nss = $xml->{'DomainDNSGetListResult'}->{'Nameserver'};
$nss = [ $nss ] if (!ref($nss));
return $nss;
}

# type_namecheap_set_nameservers(&account, &domain, [&nameservers])
# Updates the nameservers for a domain to match DNS. Returns undef on success
# or an error message on failure.
sub type_namecheap_set_nameservers
{
my ($account, $d, $nss) = @_;

# Get nameservers in DNS
$nss ||= &get_domain_nameservers($account, $d);
if (!ref($nss)) {
	return $nss;
	}
elsif (!@$nss) {
	return $text{'rcom_ensrecords'};
	}
elsif (@$nss < 2) {
	return &text('namecheap_enstwo', 2, $nss->[0]);
	}

# Set the nameservers
$d->{'dom'} =~ /^([^\.]+)\.(\S+)$/ || return "Invalid domain name $d->{'dom'}";
my ($sld, $tld) = ($1, $2);
my ($ok, $xml) = &call_namecheap_api($account,
	"namecheap.domains.dns.setCustom",
	{ 'SLD' => $sld, 'TLD' => $tld,
	  'Nameservers' => join(",", @$nss) });

return $ok ? undef : $xml;
}

# type_namecheap_get_expiry(&account, &domain)
# Returns either 1 and the expiry time (unix) for a domain, or 0 and an error
# message.
sub type_namecheap_get_expiry
{
my ($account, $d) = @_;
my ($ok, $xml) = &call_namecheap_api($account,
	"namecheap.domains.getinfo",
	{ 'DomainName' => $d->{'dom'} });
return (0, &text('namecheap_error', $xml)) if (!$ok);

my $t = $xml->{'DomainGetInfoResult'}->{'DomainDetails'}->{'ExpiredDate'};
if ($t =~ /(\d+)\/(\d+)\/(\d+)/) {
	return (1, timelocal(0, 0, 0, $2, $1-1, $3-1900));
	}
return (0, &text('gandi_eexpiry', $t));
}

# type_namecheap_renew_domain(&account, &domain, years)
# Attempts to renew a domain for the specified period. Returns 1 and the
# registrars confirmation code on success, or 0 and an error message on
# failure.
sub type_namecheap_renew_domain
{
my ($account, $d, $years) = @_;
my ($ok, $xml) = &call_namecheap_api($account,
	"namecheap.domains.renew",
	{ 'DomainName' => $d->{'dom'},
	  'Years' => $years });
return (0, &text('namecheap_error', $xml)) if (!$ok);
return (1, $xml->{'DomainRenewResult'}->{'OrderID'});
}

# type_namecheap_add_instructions()
# Returns HTML for instructions to be shown on the account adding form, such
# as where to create one.
sub type_namecheap_add_instructions
{
return &text('namecheap_instructions',
	     'https://www.namecheap.com/myaccount/signup/',
	     'https://www.namecheap.com/support/api/intro/');
}

# type_namecheap_transfer_domain(&account, &domain, key)
# Transfer a domain from whatever registrar it is currently hosted with to
# this Namecheap account. Returns 1 and an order ID on succes, or 0
# and an error mesasge on failure. If a number of years is given, also renews
# the domain for that period.
sub type_namecheap_transfer_domain
{
my ($account, $d, $key, $years) = @_;

# Get my nameservers
my $nss = &get_domain_nameservers($account, $d);
if (!ref($nss)) {
        return (0, $nss);
        }
elsif (!@$nss) {
        return (0, $text{'rcom_ensrecords'});
        }
elsif (@$nss < 2) {
	return (0, &text('namecheap_enstwo', 2, $nss->[0]));
	}

# Start the transfer
my ($ok, $xml) = &call_namecheap_api($account,
	"namecheap.domains.transfer.create",
	{ 'DomainName' => $d->{'dom'},
	  'Years' => $years,
	  'EPPCode' => $key });
return (0, &text('namecheap_error', $xml)) if (!$ok);
my $tid = $xml->{'DomainTransferCreateResult'}->{'TransferID'};

# Poll for completion
my $tries = 0;
my $t;
while($tries++ < 300) {
	sleep(1);
	my ($ok, $xml) = &call_namecheap_api($account,
		"namecheap.domains.transfer.getList");
	next if (!$ok);
	($t) = grep { $_->{'Domainname'} eq $d->{'dom'} }
		    @{$xml->{'TransferGetListResult'}->{'Transfer'}};
	next if (!$t);
	if ($t->{'Status'} eq 'CANCELLED') {
		return (0, $t->{'StatusDescription'});
		}
	elsif ($t->{'Status'} eq 'COMPLETED') {
		return (1, $t->{'OrderID'});
		}
	}

# Timed out
return (0, $t ? &text('namecheap_etransfer', $t->{'StatusDescription'})
	      : $text{'namecheap_etransfer2'});
}

# type_namecheap_delete_domain(&account, &domain)
# Deletes a domain previously created with this registrar
sub type_namecheap_delete_domain
{
my ($account, $d) = @_;

my ($ok, $xml) = &call_namecheap_api($account,
	"namecheap.domains.delete", { 'DomainName' => $d->{'dom'} });
return (0, &text('namecheap_error', $xml)) if (!$ok);

return (1, $d->{'dom'});
}

# type_namecheap_get_contact(&account, &domain)
# Returns a array containing hashes of domain contact information, or an error
# message if it could not be found.
sub type_namecheap_get_contact
{
my ($account, $d) = @_;

my ($ok, $xml) = &call_namecheap_api($account,
		"namecheap.domains.getContacts",
		{ 'DomainName' => $d->{'dom'} });
$ok || return &text('namecheap_error', $xml);

my @rv;
my @schema = &type_namecheap_get_contact_schema($account, $d);
foreach my $t (keys %{$xml->{'DomainContactsResult'}}) {
	my $con = $xml->{'DomainContactsResult'}->{$t};
        next if (!$con->{'FirstName'});
	$con->{'purpose'} = $t;
	foreach my $s (@schema) {
		my $v = $con->{$s->{'name'}};
		if (ref($v) eq 'HASH') {
			$v = join(",", keys %$v);
			}
		elsif (ref($v) eq 'ARRAY') {
			$v = @$v;
			}
		$con->{$s->{'name'}} = $v;
		}
	push(@rv, $con);
	}

return \@rv;
}

# type_namecheap_save_contact(&account, &domain, &contacts)
# Updates contacts from an array of hashes
sub type_namecheap_save_contact
{
my ($account, $d, $cons) = @_;
my %params = ( 'DomainName' => $d->{'dom'} );
foreach my $con (@$cons) {
	foreach my $k (keys %$con) {
		next if ($k eq 'purpose');
		$params{$con->{'purpose'}.$k} = $con->{$k};
		}
	}
my ($ok, $xml) = &call_namecheap_api($account,
                "namecheap.domains.setContacts", \%params);
$ok || return &text('namecheap_error', $xml);

return undef;
}

# type_namecheap_get_contact_schema(&account, &domain, type)
# Returns a list of fields for domain contacts, as seen by register.com
sub type_namecheap_get_contact_schema
{
my ($account, $d, $type) = @_;
return (
	      { 'name' => 'FirstName',
		'size' => 40,
		'opt' => 0 },
	      { 'name' => 'LastName',
		'size' => 40,
		'opt' => 0 },
	      { 'name' => 'OrganizationName',
		'size' => 60,
		'opt' => 1 },
	      { 'name' => 'JobTitle',
		'size' => 60,
		'opt' => 1 },
	      { 'name' => 'Address1',
		'size' => 60,
		'opt' => 0 },
	      { 'name' => 'Address2',
		'size' => 60,
		'opt' => 2 },
	      { 'name' => 'City',
		'size' => 40,
		'opt' => 0 },
	      { 'name' => 'StateProvinceChoice',
		'choices' => [ [ 'S', 'State' ], [ 'P', 'Province' ] ],
		'opt' => 1 },
	      { 'name' => 'StateProvince',
		'size' => 40,
		'opt' => 1 },
	      { 'name' => 'PostalCode',
		'size' => 20,
		'opt' => 1 },
	      { 'name' => 'Country',
		'choices' => [ map { [ $_->[1], $_->[0] ] } &list_countries() ],
		'opt' => 0 },
	      { 'name' => 'EmailAddress',
		'size' => 60,
		'opt' => 0 },
	      { 'name' => 'Phone',
		'size' => 40,
		'opt' => 0 },
	      { 'name' => 'PhoneExt',
		'size' => 40,
		'opt' => 1 },
	      { 'name' => 'Fax',
		'size' => 40,
		'opt' => 1 },
	);
}



# call_namecheap_api(&account, command, &params)
# Calls the namecheap API, and returns a status code and either error message
# or a results object.
sub call_namecheap_api
{
my ($account, $cmd, $params) = @_;
my $url = $account->{'namecheap_test'} ? $namecheap_api_url_test
					  : $namecheap_api_url;
my ($host, $port, $page, $ssl) = &parse_http_url($url);
$page .= "?APIUser=".&urlize($account->{'namecheap_user'}).
	 "&ApiKey=".&urlize($account->{'namecheap_apikey'}).
	 "&UserName=".&urlize($account->{'namecheap_user'}).
	 "&ClientIP=".($account->{'namecheap_ip'} ||
		       &virtual_server::get_dns_ip() ||
		       &virtual_server::get_default_ip()).
	 "&Command=".&urlize($cmd);
my $data = "";
if ($params) {
	foreach my $p (keys %$params) {
		my $v = $params->{$p};
		if (ref($v) eq 'HASH') {
			$v = join(",", keys %$v);
			}
		elsif (ref($v) eq 'ARRAY') {
			$v = @$v;
			}
		$data .= "&".$p."=".&urlize($v);
		}
	}
$data =~ s/^\&//;
my ($out, $err);
&http_post($host, $port, $page, $data, \$out, \$err, undef, $ssl);
return (0, $err) if ($err);
return (0, "Invalid response : $out") if ($out !~ /^\s*</);
my $xml;
eval {
	$xml = XMLin($out);
	};
return (0, "Invalid response XML : $@") if ($@);
return (0, "API command failed : $xml->{'Errors'}->{'Error'}->{'content'}")
	if ($xml->{'Status'} ne 'OK');
return (1, $xml->{'CommandResponse'});
}

1;
