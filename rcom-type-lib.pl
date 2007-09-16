# Functions for talking to register.com

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
	&ui_textbox("rcom_pass", $pass->{'rcom_pass'}, 30));
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
# XXX
}

1;

