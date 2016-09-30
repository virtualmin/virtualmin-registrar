use strict;
no strict 'refs';
use warnings;
our %access;
our $module_name;

do 'virtualmin-registrar-lib.pl';

sub cgi_args
{
my ($cgi) = @_;
no warnings "once";
my ($d) = grep { &virtual_server::can_edit_domain($_) &&
	         $_->{$module_name} } &virtual_server::list_domains();
use warnings "once";
if ($cgi eq 'edit_contact.cgi' || $cgi eq 'edit_dereg.cgi' ||
    $cgi eq 'edit_ns.cgi' || $cgi eq 'edit_renew.cgi') {
	# Domain-based form
	return $d ? 'dom='.&urlize($d->{'dom'}) : 'none';
	}
elsif ($cgi eq 'edit.cgi') {
	# Show first account
	my @accounts = &list_registrar_accounts();
	return !$access{'registrar'} ? 'none' :
	       @accounts ? 'id='.$accounts[0]->{'id'} :
			   'registrar=rcom';
	}
elsif ($cgi eq 'list.cgi') {
	# Works with no args
	return '';
	}
elsif ($cgi eq 'create_form.cgi') {
	return 'registrar=rcom';
	}
return undef;
}
