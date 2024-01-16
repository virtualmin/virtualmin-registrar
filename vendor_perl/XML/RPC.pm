
=head1 NAME

XML::RPC -- Pure Perl implementation for an XML-RPC client and server.

=head1 SYNOPSIS

make a call to an XML-RPC server:

    use XML::RPC;

    my $xmlrpc = XML::RPC->new('http://betty.userland.com/RPC2');
    my $result = $xmlrpc->call( 'examples.getStateStruct', { state1 => 12, state2 => 28 } );

create an XML-RPC service:

    use XML::RPC;
    use CGI;

    my $q      = new CGI;
    my $xmlrpc = XML::RPC->new();
    my $xml    = $q->param('POSTDATA');

    print $q->header( -type => 'text/xml', -charset => 'UTF-8' );
    print $xmlrpc->receive( $xml, \&handler );

    sub handler {
        my ( $methodname, @params ) = @_;
        return { you_called => $methodname, with_params => \@params };
    }

=head1 WARNING

Very little maintainance goes into this module. While it continues to work, is has certain quirks that may or may not be fixable without breaking backward compatibility.

I strongly recommend that, before deciding what to use in a new project, you look into Randy Ray's L<RPC::XML> module. This seems to be a much more modern approach.

=head1 DESCRIPTION

XML::RPC module provides simple Pure Perl methods for XML-RPC communication.
It's goals are simplicity and flexibility. XML::RPC uses XML::TreePP
for parsing.

This version of XML::RPC merges the changes from XML::RPC::CustomUA.

=head1 CONSTRUCTOR AND OPTIONS

=head2 $xmlrpc = XML::RPC->new();

This constructor method returns a new XML::RPC object. Usable for XML-RPC servers.

=head2 $xmlrpc = XML::RPC->new( 'http://betty.userland.com/RPC2', %options );

Its first argument is the full URL for your server. The second argument
is for options passing to XML::TreePP, for example: output_encoding => 'ISO-8859-1'
(default is UTF-8).

You can also define the UserAgent string, for example:

    my $rpcfoo = XML::RPC->new($apiurl, ('User-Agent' => 'Baz/3000 (Mozilla/1.0; FooBar phone app)'));

=head1 METHODS

=head2 $xmlrpc->credentials( 'username', 'password );

Set Credentials for HTTP Basic Authentication. This is only
secure over HTTPS.

Please, please, please do not use this over unencrypted connections!

=head2 $xmlrpc->call( 'method_name', @arguments );

This method calls the provides XML-RPC server's method_name with
@arguments. It will return the server method's response.

=head2 $xmlrpc->receive( $xml, \&handler );

This parses an incoming XML-RPC methodCall and call the \&handler subref
with parameters: $methodName and @parameters.

=head2 $xmlrpc->xml_in();

Returns the last XML that went in the client.

=head2 $xmlrpc->xml_out();

Returns the last XML that went out the client.

=head2 $xmlrpc->indent(indentsize);

Sets the xmlout indentation

=head1 CUSTOM TYPES

=head2 $xmlrpc->call( 'method_name', { data => sub { { 'base64' => encode_base64($data) } } } );

When passing a CODEREF to a value XML::RPC will simply use the returned hashref as a type => value pair.

=head1 TYPECASTING

Sometimes a value type might not be clear from the value alone, typecasting provides a way to "force" a value to a certain type

=head2 as_string

Forces a value to be cast as string.

    $xmlrpc->call( 'gimmeallyourmoney', { cardnumber => as_string( 12345 ) } );

=head2 as_int

Forces a value to be cast as int

=head2 as_i4

Forces a value to be cast as i4

=head2 as_double

Forces a value to be cast as double

=head2 as_boolean

Forces a value to be cast as boolean

=head2 as_base64

Forces a value to be cast as base64

=head2 as_dateTime_iso8601

Forces a value to be cast as ISO8601 Datetime


=head1 ERROR HANDLING

To provide an error response you can simply die() in the \&handler
function. Also you can set the $XML::RPC::faultCode variable to a (int) value
just before dieing.

=head1 PROXY SUPPORT

Default XML::RPC will try to use LWP::Useragent for requests,
you can set the environment variable: CGI_HTTP_PROXY to
set a proxy.

=head1 LIMITATIONS

XML::RPC will not create "bool", "dateTime.iso8601" or "base64" types
automatically. They will be parsed as "int" or "string". You can use the 
CODE ref to create these types.

=head1 AUTHOR

Original author: Niek Albers, http://www.daansystems.com/
Current author: Rene Schickbauer, https://cavac.at

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2007-2008 Niek Albers.  All rights reserved.  This program

Copyright (c) 2012-2022 Rene Schickbauer

This program is free software; you can redistribute it and/or modify it under the same
terms as Perl itself.
=cut

package XML::RPC;

use strict;
use XML::TreePP;
use MIME::Base64;
use Time::Local;
use vars qw($VERSION $faultCode);
no strict 'refs';

$VERSION   = 2.0;
$faultCode = 0;

sub new {
    my $package = shift;
    my $self    = {};
    bless $self, $package;
    $self->{url} = shift;
    $self->{tpp} = XML::TreePP->new(@_);
    return $self;
}

sub indent {
  my $self = shift || return;
  $self->{tpp}->set( indent => shift );
}

sub credentials {
    my ($self, $username, $password) = @_;

    my $authtoken = 'Basic ' . encode_base64($username . ':' . $password, '');

    $self->{authtoken} = $authtoken;

    return;
}

sub call {
    my $self = shift;
    my ( $methodname, @params ) = @_;

    die 'no url' if ( !$self->{url} );

    $faultCode = 0;
    my $xml_out = $self->create_call_xml( $methodname, @params );

    $self->{xml_out} = $xml_out;

    my %header = (
        'Content-Type'   => 'text/xml',
        'User-Agent'     => defined($self->{tpp}->{'User-Agent'}) ? $self->{tpp}->{'User-Agent'} : 'XML-RPC/' . $VERSION,
        'Content-Length' => length($xml_out)
    );

    if(defined($self->{authtoken})) {
        $header{'Authorization'} = $self->{authtoken}
    }

    my ( $result, $xml_in ) = $self->{tpp}->parsehttp(
        POST => $self->{url},
        $xml_out,
        \%header,
    );

    $self->{xml_in} = $xml_in;

    my @data = $self->unparse_response($result);
    return @data == 1 ? $data[0] : @data;
}

sub receive {
    my $self   = shift;
    my $result = eval {
        my $xml_in = shift || die 'no xml';
        $self->{xml_in} = $xml_in;
        my $handler = shift || die 'no handler';
        my $hash = $self->{tpp}->parse($xml_in);
        my ( $methodname, @params ) = $self->unparse_call($hash);
        $self->create_response_xml( $handler->( $methodname, @params ) );
    };

    $result = $self->create_fault_xml($@) if ($@);
    $self->{xml_out} = $result;
    return $result;

}

sub create_fault_xml {
    my $self  = shift;
    my $error = shift;
    chomp($error);
    return $self->{tpp}
      ->write( { methodResponse => { fault => $self->parse( { faultString => $error, faultCode => int($faultCode) } ) } } );
}

sub create_call_xml {
    my $self = shift;
    my ( $methodname, @params ) = @_;

    return $self->{tpp}->write(
        {
            methodCall => {
                methodName => $methodname,
                params     => { param => [ map { $self->parse($_) } @params ] }
            }
        }
    );
}

sub create_response_xml {
    my $self   = shift;
    my @params = @_;

    return $self->{tpp}->write( { methodResponse => { params => { param => [ map { $self->parse($_) } @params ] } } } );
}

sub parse {
    my $self = shift;
    my $p    = shift;
    my $result;

    if ( ref($p) eq 'HASH' ) {
        $result = $self->parse_struct($p);
    }
    elsif ( ref($p) eq 'ARRAY' ) {
        $result = $self->parse_array($p);
    }
    elsif ( ref($p) eq 'CODE' ) {
        $result = $p->();
    }
    else {
        $result = $self->parse_scalar($p);
    }

    return { value => $result };
}

sub parse_scalar {
    my $self   = shift;
    my $scalar = shift;
    local $^W = undef;

    if (   ( $scalar =~ m/^[\-+]?(0|[1-9]\d*)$/ )
        && ( abs($scalar) <= ( 0xffffffff >> 1 ) ) )
    {
        return { i4 => $scalar };
    }
    elsif ( $scalar =~ m/^[\-+]?\d+\.\d+$/ ) {
        return { double => $scalar };
    }
    else {
        return { string => \$scalar };
    }
}

sub parse_struct {
    my $self = shift;
    my $hash = shift;

    return { struct => { member => [ map { { name => $_, %{ $self->parse( $hash->{$_} ) } } } keys(%$hash) ] } };
}

sub parse_array {
    my $self  = shift;
    my $array = shift;

    return { array => { data => { value => [ map { $self->parse($_)->{value} } $self->list($array) ] } } };
}

sub unparse_response {
    my $self = shift;
    my $hash = shift;

    my $response = $hash->{methodResponse} || die 'no data';

    if ( $response->{fault} ) {
        return $self->unparse_value( $response->{fault}->{value} );
    }
    else {
        return map { $self->unparse_value( $_->{value} ) } $self->list( $response->{params}->{param} );
    }
}

sub unparse_call {
    my $self = shift;
    my $hash = shift;

    my $response = $hash->{methodCall} || die 'no data';

    my $methodname = $response->{methodName};
    my @args =
      map { $self->unparse_value( $_->{value} ) } $self->list( $response->{params}->{param} );
    return ( $methodname, @args );
}

sub unparse_value {
    my $self  = shift;
    my $value = shift;
    my $result;

    return $value if ( ref($value) ne 'HASH' );    # for unspecified params
    if ( $value->{struct} ) {
        $result = $self->unparse_struct( $value->{struct} );
        return !%$result
          ? undef
          : $result;                               # fix for empty hashrefs from XML::TreePP
    }
    elsif ( $value->{array} ) {
        return $self->unparse_array( $value->{array} );
    }
    else {
        return $self->unparse_scalar($value);
    }
}

sub unparse_scalar {
    my $self     = shift;
    my $scalar   = shift;
    my ($result) = values(%$scalar);
    return ( ref($result) eq 'HASH' && !%$result )
      ? undef
      : $result;    # fix for empty hashrefs from XML::TreePP
}

sub unparse_struct {
    my $self   = shift;
    my $struct = shift;

    return { map { $_->{name} => $self->unparse_value( $_->{value} ) } $self->list( $struct->{member} ) };
}

sub unparse_array {
    my $self  = shift;
    my $array = shift;
    my $data  = $array->{data};

    return [ map { $self->unparse_value($_) } $self->list( $data->{value} ) ];
}

sub list {
    my $self  = shift;
    my $param = shift;
    return () if ( !$param );
    return @$param if ( ref($param) eq 'ARRAY' );
    return ($param);
}

sub xml_in { shift->{xml_in} }

sub xml_out { shift->{xml_out} }

# private helper function to create specialised closure
sub _cast {
    my ($type, $val) = @_;
    return sub { return { "$type" => $val }; };
}

sub as_string {
    return _cast( 'string', shift );
}

sub as_int {
    return _cast( 'int', int shift );
}

sub as_i4 {
    return _cast( 'i4',      int shift );
}

sub as_double  {
    return _cast( 'double',  sprintf('%g', shift) );
}

sub as_boolean {
    return _cast( 'boolean', (shift) ? '1' : '0' );
}

sub as_base64 {
    chomp( my $base64 = encode_base64( shift ) );
    return _cast( 'base64', $base64 );
}

# converts epoch (or current time if undef) to dateTime.iso8601 (UTC)
sub as_dateTime_iso8601 {
  my $epoch = shift;
  $epoch = time() unless defined $epoch; # could be: "shift // time" with modern perl versions
  my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) = gmtime( $epoch );

  return _cast( 'dateTime.iso8601',
                sprintf('%4d%02d%02dT%02d:%02d:%02dZ',
                        $year + 1900, $mon + 1, $mday, $hour, $min, $sec)
              );
}

1;
