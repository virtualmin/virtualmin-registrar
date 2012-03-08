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
local ($d, $oldd) = @_;
# Is DNS enabled?
$d->{'dns'} || return $text{'feat_edns'};
if (!$oldd || !$oldd->{$module_name}) {
	# Can we find an account for the domain?
	local $account = &find_registrar_account($d->{'dom'});
	return $text{'feat_edepend'} if (!$account);
	$d->{'dom'} =~ /\./ || $text{'feat_edepend2'};
	}
return undef;
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
local ($d) = @_;
local $account = &find_registrar_account($d->{'dom'});
local $reg = $account->{'registrar'};
local $dfunc = "type_".$reg."_desc";
&$virtual_server::first_print(&text('feat_setup', &$dfunc($account)));

# Check if the domain is already owned by this account
local $ofunc = "type_".$reg."_check_domain";
if (defined(&$ofunc)) {
	local ($o, $id) = &$ofunc($account, $d->{'dom'});
	if ($o) {
		$d->{'registrar_account'} = $account->{'id'};
		$d->{'registrar_id'} = $msg;
		&$virtual_server::second_print(&text('feat_setupalready'));
		return 1;
		}
	}

# Call the account type's register function
local $rfunc = "type_".$reg."_create_domain";
local ($ok, $msg) = &$rfunc($account, $d);
if (!$ok) {
	&error(&text('feat_failed', $msg));
	}
$d->{'registrar_account'} = $account->{'id'};
$d->{'registrar_id'} = $msg;
&$virtual_server::second_print(&text('feat_setupdone', $msg));

# Copy contacts from the user's main domain to this new one
local $gcfunc = "type_".$reg."_get_contact";
if ($d->{'parent'} && ($parent = &virtual_server::get_domain($d->{'parent'})) &&
    $parent->{$module_name} &&
    $parent->{'registrar_account'} eq $account->{'id'} &&
    defined(&$gfunc)) {
	&$virtual_server::first_print(&text('feat_copy', $parent->{'dom'}));
	local $cons = &$gcfunc($account, $parent);
	if (!ref($cons)) {
		&$virtual_server::second_print(&text('feat_ecopy', $cons));
		}
	elsif (!@$cons) {
		&$virtual_server::second_print(&text('feat_nocopy'));
		}
	else {
		local $scfunc = "type_".$reg."_save_contact";
		local $err = &$scfunc($account, $d, $cons);
		if ($err) {
			&$virtual_server::second_print(
				&text('feat_ecopy2', $err));
			}
		else {
			&$virtual_server::second_print(
				$virtual_server::text{'setup_done'});
			}
		}
	}
return 1;
}

# feature_modify(&domain, &olddomain)
# Called when a domain with this feature is modified
sub feature_modify
{
local ($d, $oldd) = @_;
if ($d->{'dom'} eq $oldd->{'dom'}) {
	# Nothing to do if domain name hasn't changed
	return;
	}
local ($account) = grep { $_->{'id'} eq $oldd->{'registrar_account'} }
			&list_registrar_accounts();
if (!$account) {
	&error($text{'feat_noaccount'});
	return 0;
	}
local $reg = $account->{'registrar'};
local $dfunc = "type_".$reg."_desc";
local $mfunc = "type_".$reg."_rename_domain";
if (defined(&$mfunc)) {
	# Registrar provides a rename function
	&$virtual_server::first_print(&text('feat_modify', $oldd->{'dom'},
					    $d->{'dom'}, &$dfunc($account)));
	local ($ok, $msg) = &$mfunc($account, $d, $oldd);
	if (!$ok) {
		&error(&text('feat_failed', $msg));
		return 0;
		}
	$d->{'registrar_account'} = $account->{'id'};
	$d->{'registrar_id'} = $msg;
	&$virtual_server::second_print(&text('feat_setupdone', $msg));
	}
else {
	# Need to take down and re-create
	&$virtual_server::first_print(&text('feat_modify1', $oldd->{'dom'},
					    &$dfunc($account)));
	local $gcfunc = "type_".$reg."_get_contact";
	local $cons;
	if (defined(&$gcfunc)) {
		$cons = &$gcfunc($account, $oldd);
		}
	local $ufunc = "type_".$reg."_delete_domain";
	local ($ok, $msg) = &$ufunc($account, $oldd);
	if (!$ok) {
		&error(&text('feat_failed', $msg));
		return 0;
		}
	delete($d->{'registrar_account'});
	delete($d->{'registrar_id'});
	&$virtual_server::second_print($virtual_server::text{'setup_done'});

	# Re-create .. hope this works!
	&$virtual_server::first_print(&text('feat_modify2', $d->{'dom'},
					    &$dfunc($account)));
	local $rfunc = "type_".$reg."_create_domain";
	local ($ok, $msg) = &$rfunc($account, $d);
	if (!$ok) {
		&error(&text('feat_failed', $msg));
		return 0;
		}
	$d->{'registrar_account'} = $account->{'id'};
	$d->{'registrar_id'} = $msg;
	if (ref($cons) && @$cons > 0) {
		local $scfunc = "type_".$reg."_save_contact";
		if (defined(&$scfunc)) {
			&$scfunc($account, $d, $cons);
			}
		}
	&$virtual_server::second_print(&text('feat_setupdone', $msg));
	}
}

# feature_delete(&domain)
# Called when this feature is disabled, or when the domain is being deleted
sub feature_delete
{
local ($d) = @_;
local ($account) = grep { $_->{'id'} eq $d->{'registrar_account'} }
			&list_registrar_accounts();
if (!$account) {
	&error($text{'feat_noaccount'});
	return 0;
	}
local $reg = $account->{'registrar'};
local $dfunc = "type_".$reg."_desc";
&$virtual_server::first_print(&text('feat_delete', &$dfunc($account)));
local $ufunc = "type_".$reg."_delete_domain";
local ($ok, $msg) = &$ufunc($account, $d);
if (!$ok) {
	&error(&text('feat_failed', $msg));
        return 0;
	}
delete($d->{'registrar_account'});
delete($d->{'registrar_id'});
&$virtual_server::second_print($virtual_server::text{'setup_done'});
return 1;
}

# feature_inputs_show([&domain])
# Always show registration period, if any accounts
sub feature_inputs_show
{
local @accounts = grep { $_->{'enabled'} } &list_registrar_accounts();
return @accounts ? 1 : 0;
}

# feature_inputs([&domain])
# Return field for registration period
sub feature_inputs
{
return &ui_table_row($text{'feat_period'},
	&ui_opt_textbox($input_name."_period", undef, 5,
			$text{'feat_perioddef'})." ".
	$text{'feat_periodyears'});
}

# feature_inputs_parse(&domain, &in)
# Update the domain object with a custom registration period, if requested
sub feature_inputs_parse
{
local ($d, $in) = @_;
if (defined($in->{$input_name."_period"}) &&
    !$in->{$input_name."_period_def"}) {
	$in->{$input_name."_period"} =~ /^\d+$/ ||
		return $text{'feat_eperiod'};
	$d->{'registrar_years'} = $in->{$input_name."_period"};
	}
return undef;
}

# feature_args(&domain)
# Return command-line arguments for domain registration
sub feature_args
{
return ( { 'name' => $module_name."-period",
	   'value' => 'years',
	   'opt' => 1,
	   'desc' => 'Period to register a new domain for' },
       );
}

# feature_args_parse(&domain, &args)
# Parse command-line arguments from feature_args
sub feature_args_parse
{
local ($d, $args) = @_;
if (defined($args->{$module_name."-period"})) {
	$args->{$module_name."-period"} =~ /^\d+$/ ||
		return "Registration period must be a number of years";
	$d->{'registrar_years'} = $args->{$module_name."-period"};
	}
return undef;
}

# feature_always_links(&domain)
# Returns an array of link objects for webmin modules, regardless of whether
# this feature is enabled or not
sub feature_always_links
{
# Return links to edit domain contact details and import/de-import
local ($d) = @_;
local @rv;
local @accounts = &list_registrar_accounts();
if ($d->{$module_name}) {
	# Edit contact details
	local ($account) = grep { $_->{'id'} eq $d->{'registrar_account'} }
				@accounts;
	local $cfunc = "type_".$account->{'registrar'}."_get_contact";
	local $cm = &can_contacts($d);
	if ($cm && defined(&$cfunc)) {
		push(@rv, { 'mod' => $module_name,
			    'desc' => $cm == 1 || $cm == 3 ?
					$text{'links_contact'} :
					$text{'links_contactv'},
			    'page' => $cm == 1 || $cm == 3 ? 
				'edit_contact.cgi?dom='.$d->{'dom'} :
				'view_contact.cgi?dom='.$d->{'dom'},
			    'cat' => 'dns' });
		}

	# Show and allow editing of nameservers
	local $nfunc = "type_".$account->{'registrar'}."_get_nameservers";
	local $cn = &can_nameservers($d);
	if ($cn && defined(&$nfunc)) {
		push(@rv, { 'mod' => $module_name,
			    'desc' => $text{'links_ns'},
			    'page' => 'edit_ns.cgi?dom='.$d->{'dom'},
			    'cat' => 'dns' });
		}

	# Renew domain (if allowed to create)
	if (&virtual_server::can_use_feature($module_name)) {
		push(@rv, { 'mod' => $module_name,
			    'desc' => $text{'links_renew'},
			    'page' => 'edit_renew.cgi?dom='.$d->{'dom'},
			    'cat' => 'dns' });
		}

	# Dis-associate
	if ($access{'registrar'}) {
		push(@rv, { 'mod' => $module_name,
			    'desc' => $text{'links_rereg'},
			    'page' => 'edit_dereg.cgi?dom='.$d->{'dom'},
			    'cat' => 'dns' });
		}
	}
else {
	# Can import existing registration (master admin only)
	if (scalar(@accounts) && !$d->{'subdom'} && $access{'registrar'} &&
	    $d->{'dns'}) {
		push(@rv, { 'mod' => $module_name,
			    'desc' => $text{'links_import'},
			    'page' => 'edit_import.cgi?dom='.$d->{'dom'},
			    'cat' => 'dns' });
		}

	# Can request a domain transfer
	my $cantransfer = 0;
	foreach my $a (@accounts) {
		my $tfunc = "type_".$a->{'registrar'}."_transfer_domain";
		$cantransfer = 1 if (defined(&$tfunc));
		}
	if (scalar(@accounts) && !$d->{'subdom'} && $access{'registrar'} &&
	    $d->{'dns'} && $cantransfer && !$d->{'registrar_transferred'}) {
		push(@rv, { 'mod' => $module_name,
			    'desc' => $text{'links_transfer'},
			    'page' => 'edit_transfer.cgi?dom='.$d->{'dom'},
			    'cat' => 'dns' });
		}
	}
return @rv;
}

# feature_webmin(&main-domain, &all-domains)
# Returns a list of webmin module names and ACL hash references to be set for
# the Webmin user when this feature is enabled
sub feature_webmin
{
local ($d, $doms) = @_;
local @rdoms = grep { $_->{$module_name} } @$doms;
if (@rdoms) {
	return ( [ $module_name,
		   { 'registrar' => 0,
		     'doms' => join(' ', map { $_->{'dom'} } @rdoms) } ] );
	}
return ( );
}

# feature_validate(&domain)
# Checks if this feature is properly setup for the virtual server, and returns
# an error message if any problem is found
sub feature_validate
{
return undef;
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

