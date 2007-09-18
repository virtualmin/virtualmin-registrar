# Defines functions for this feature

do 'virtualmin-registrar-lib.pl';

# feature_name()
# Returns a short name for this feature
sub feature_name
{
return $text{'feat_name'};
}

# feature_losing(&domain)
# Returns a description of what will be deleted when this feature is removed
sub feature_losing
{
return $text{'feat_losing'};
}

# feature_disname(&domain)
# Returns a description of what will be turned off when this feature is disabled
sub feature_disname
{
return $text{'feat_disabling'};
}

# feature_label(in-edit-form)
# Returns the name of this feature, as displayed on the domain creation and
# editing form
sub feature_label
{
return $text{'feat_label'};
}

# feature_hlink(in-edit-form)
# Returns a help page linked to by the label returned by feature_label
sub feature_hlink
{
return "label";
}

# feature_depends(&domain)
# Returns undef if all pre-requisite features for this domain are enabled,
# or an error message if not
sub feature_depends
{
local ($d) = @_;
# Is DNS enabled?
$d->{'dns'} || return $text{'feat_edns'};
# Can we find an account for the domain?
local $account = &find_registrar_account($d->{'dom'});
return $text{'feat_edepend'} if (!$account);
$d->{'dom'} =~ /\./ || $text{'feat_edepend2'};
}

# feature_clash(&domain)
# Returns undef if there is no clash for this domain for this feature, or
# an error message if so
sub feature_clash
{
# Is this domain already registered?
local ($d) = @_;
local $account = &find_registrar_account($d->{'dom'});
return $text{'feat_edepend'} if (!$account);
local $cfunc = "type_".$account->{'registrar'}."_check_domain";
if (defined(&$cfunc)) {
	local $cerr = &$cfunc($account, $d->{'dom'});
	if ($cerr) {
		return &text('feat_eclash', $d->{'dom'}, $cerr);
		}
	}
return undef;
}

# feature_suitable([&parentdom], [&aliasdom], [&subdom])
# Returns 1 if some feature can be used with the specified alias,
# parent and sub domains
sub feature_suitable
{
# Cannot use anywhere except subdoms if no accounts have been setup
local ($parentdom, $aliasdom, $subdom) = @_;
return 0 if ($subdom);
local @accounts = grep { $_->{'enabled'} } &list_registrar_accounts();
return scalar(@accounts) ? 1 : 0;
}

# feature_setup(&domain)
# Called when this feature is added, with the domain object as a parameter
sub feature_setup
{
# Call the account type's register function
local ($d) = @_;
local $account = &find_registrar_account($d->{'dom'});
local $reg = $account->{'registrar'};
local $dfunc = "type_".$reg."_desc";
&$virtual_server::first_print(&text('feat_setup', &$dfunc($account)));
local $rfunc = "type_".$reg."_create_domain";
local $err = &$rfunc($account, $d);
if ($err) {
	&$virtual_server::second_print(&text('feat_failed', $err));
	return 0;
	}
$d->{'registrar_account'} = $account->{'id'};
&$virtual_server::second_print($virtual_server::text{'setup_done'});
return 1;
}

# feature_modify(&domain, &olddomain)
# Called when a domain with this feature is modified
sub feature_modify
{
# XXX call the API
}

# feature_delete(&domain)
# Called when this feature is disabled, or when the domain is being deleted
sub feature_delete
{
# XXX call the API
}

# feature_disable(&domain)
# Called when this feature is temporarily disabled for a domain
# (optional)
sub feature_disable
{
# XXX call the API
}

# feature_enable(&domain)
# Called when this feature is re-enabled for a domain
# (optional)
sub feature_enable
{
# XXX call the API
}

# feature_links(&domain)
# Returns an array of link objects for webmin modules for this feature
sub feature_links
{
# XXX whois info?
}

# feature_validate(&domain)
# Checks if this feature is properly setup for the virtual server, and returns
# an error message if any problem is found
sub feature_validate
{
# XXX check if really registered
}

# settings_links()
# If defined, should return a list of additional System Settings section links
# related to this plugin, typically for configuring global settings. Each
# element must be a hash ref containing link, title, icon and cat keys.
sub settings_links
{
return ( { "link" => "$module_name/index.cgi",
	   "title" => $text{"index_title"},
	   "icon" => "$gconfig{'webprefix'}/$module_name/images/icon.gif",
	   "cat" => "ip" } );
}

1;

