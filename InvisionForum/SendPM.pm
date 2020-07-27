package InvisionForum::SendPM;

use warnings;
use strict;
use Carp;

use WWW::Mechanize;
use HTML::Entities;

BEGIN 
{
	$| = 1;
	binmode STDOUT, ":utf8";
}

#
# Private methods
#

my $_sendmessage = sub 
{
	my $self		= shift(@_);

	my @messages;

	my $data;
	my $csrfkey;

	$self->{_browser}->get
	(
		$self->{_domain} . "/messenger/" 
	);

	if ($self->{_browser}->success)
	{
		if ($self->{_browser}->response()->decoded_content())
		{
			$data = $self->{_browser}->response()->decoded_content();
			while ($data =~ m#/messenger/(\d+)/#g)
			{
				push(@messages, $1);
			}
			($csrfkey) = $self->{_browser}->response()->decoded_content() =~ /csrfKey: "(.*?)",/;
		}
		else
		{
			die 'Decoding content problem';
		}
	}
	else
	{
		die 'Request message problem';
	}

	if (scalar(@messages)>0)
	{
		for (@messages)
		{
			$self->{_browser}->get
			(
				$self->{_domain} 
				. "/index.php?app=core&module=messaging&controller=messenger&do=leaveConversation&csrfKey=" 
				. $csrfkey
				. "&id=" 
				. $_
			);
		}
	}

	$self->{_browser}->get
	(
		$self->{_domain} . "/messenger/compose/" 
	);

	if ($self->{_browser}->success)
	{
		if ($self->{_browser}->response()->decoded_content())
		{
			($csrfkey) = $self->{_browser}->response()->decoded_content() =~ /csrfKey: "(.*?)",/;
		}
		else
		{
			die 'Decoding content problem';
		}
	}
	else
	{
		die 'Request message problem';
	}

	$self->{_browser}->post
	(
		$self->{_domain} . "/messenger/compose/",
		content =>
		{
			messenger_content			=> $_[2],
			form_submitted				=> 1,
			csrfKey 					=> $csrfkey,
			messenger_to_original		=> '',
			messenger_to				=> $_[0],
			messenger_title				=> $_[1],
		}
	);

	if ($self->{_browser}->success)
	{
		if ($self->{_browser}->response()->decoded_content())
		{
			if ( index( $self->{_browser}->title() , $_[1] ) != -1 )
			{
				print "[+] Message sent / " . $_[0] . "\r\n" if $self->{_debug};
				return 1;
			}
			else
			{
				die 'User dont receive messages';
			}
		}
		else
		{
			die 'Decoding content problem';
		}
	}
	else
	{
		die 'Request message problem';
	}
};

my $_login = sub
{
	my $self		= shift(@_);

	my $csrfkey;

	$self->{_browser} = WWW::Mechanize->new
	(
		agent => $self->{_ua},
		ssl_opts => 
		{
			verify_hostname => 0,
			SSL_verify_mode => 0,
		},
		timeout => 15,
	);

#	Control IN/OUT HEADERS
#	$self->{_browser}->add_handler("request_send", sub { shift->dump; return });
#	$self->{_browser}->add_handler("response_done", sub { shift->dump; return });	

	$self->{_browser}->proxy
	( 
		['http','https'],"http://" 
		. $self->{_proxyhost} . ":" . $self->{_proxyport} . "/" 
	) if ($self->{_proxyhost} && $self->{_proxyport});
	$self->{_browser}->get
	( 
		$self->{_domain} . "/?_fromLogin=1"
	);

	if ($self->{_browser}->success)	
	{
		if ($self->{_browser}->response()->decoded_content())
		{
			$csrfkey = ($self->{_browser}->find_all_inputs(name => 'csrfKey'))[0]->value;
		}
		else
		{
			die 'Decoding content problem';
		}
	}
	else
	{
		die 'Request problem';
	}

	$self->{_browser}->post
	(
		$self->{_domain} . "/login/",
		content =>
		{
			auth						=> $_[0],
			password					=> $_[1],
			remember_me					=> 0,
			signin_anonymous			=> 0,
			_processLogin 				=> 'usernamepassword',
			csrfKey 					=> $csrfkey,
		}
	);	

	# Old Invision
	#$self->{_browser}->submit_form
	#(
	#	form_number => 1,
	#	fields      => 
	#	{
	#		auth						=> $_[0],
	#		password					=> $_[1],
	#		remember_me					=> 0,
	#		remember_me_checkbox		=> 1,
	#		signin_anonymous			=> 0,
	#		signin_anonymous_checkbox	=> 1,
	#	}
	#);

	if ($self->{_browser}->success)
	{
		if ($self->{_browser}->response()->decoded_content())
		{
			if (index($self->{_browser}->response()->decoded_content(),'signout') != -1) 
			{return 1;}

			else{ if ($self->{_browser}->response()->decoded_content() =~ /ipsMessage_error">\s*(.*?)\s*</)
			{die $1;} else { die 'Unknown error register';} }
		}
		else
		{
			die 'Decoding content problem';		
		}
	}
	else
	{
		die 'Request problem';
	}
	return 0;
};

#
# Public methods
#

sub new
{
	my $class 	= shift;

	my $self = 
	{
		_domain 	=> shift,
		_ua			=> 'Mozilla/5.0',		
	};

	for (keys % { $self })
	{ $self->{$_} or croak "@{ [ $_ ] } is required."; }

	bless $self => $class;

	return $self;
}

sub debug
{
	my $self		= shift(@_);

	$self->{_debug} = $_[0];
}

sub proxy
{
	my $self		= shift(@_);

	$self->{_proxyhost} = $_[0];
	$self->{_proxyport} = $_[1];
}

sub ua
{
	my $self		= shift(@_);

	$self->{_ua} = $_[0];
}

sub sendpm
{
	my $self	= shift(@_);

	my $res;

	eval 
	{
		if ( $self->$_login( $_[0] , $_[1] ) )
		{
			$res = $self->$_sendmessage( $_[2], $_[3], $_[4] );
		}
	};
	if ($@)
	{		
		warn "[-] " . $@ if $self->{_debug};
		return undef;
	}
	else
	{
		return $res;
	}
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

InvisionForum::Users - Automatic download users from InvisionForum.

=head1 VERSION

version 1.00

=head1 SYNOPSIS

use warnings;
use strict;

use InvisionForum::SendPM;

sub main
{
	my $invision;
	my $res;
	
	$invision = InvisionForum::SendPM->new
	(
		'https://domain.com'
	);

	$invision->debug(1);
	$invision->proxy('host', port);
	$invision->ua('Mozilla/5.0');

	$res = $invision->sendpm('login','password', 'recipient', 'topic_message', 'message');
	print "Delivered" if $res;

	return 0;
}

main();

=head1 METHODS

=over 4

=item * debug(INT)

Set print messages debugging
Default is disable, You can disable by set 0

=item * proxy(HOST,PORT)

Set proxy every request, support only HTTP proxy, default is disable.

=item * ua(USERAGENT)

Define your useragent to request, default is Mozilla/5.0

=item * sendpm(LOGIN,PASSWORD,RECIPIENT,TOPIC,MESSAGE)

SignIn on LOGIN and send message to RECIPIENT with defined TOPIC.
Return 1 if success. If have problem return undef.
For search problems sets debug().

=back