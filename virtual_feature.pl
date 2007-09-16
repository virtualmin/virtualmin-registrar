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
# XXX registrar
}

# feature_clash(&domain)
# Returns undef if there is no clash for this domain for this feature, or
# an error message if so
sub feature_clash
{
# XXX already registered?
}

# feature_suitable([&parentdom], [&aliasdom], [&subdom])
# Returns 1 if some feature can be used with the specified alias,
# parent and sub domains
sub feature_suitable
{
return 1;
}

# feature_setup(&domain)
# Called when this feature is added, with the domain object as a parameter
sub feature_setup
{
# XXX call the API
# XXX save registrar in domain object
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

