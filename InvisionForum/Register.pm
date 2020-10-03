package InvisionForum::Register;

use warnings;
use strict;
use Carp;

use WWW::Mechanize;
use InvisionForum::AntiCaptcha;

BEGIN 
{
	$| = 1;
	binmode STDOUT, ":utf8";
}

#
# Private methods
#

my $_requestregister = sub
{
	my $self = shift(@_);

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
	$self->{_browser}->proxy
	( 
		['http','https'],"http://" 
		. $self->{_proxyhost} . ":" . $self->{_proxyport} . "/"
	) if ($self->{_proxyhost} && $self->{_proxyport});

	$self->{_browser}->get
	( 
		$self->{_domain} 
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
		die 'Request message problem';
	}

	$self->{_browser}->get
	(
		$self->{_domain} . 
		"/register/?csrfKey=" . 
		$csrfkey 
	);

	$self->{_browser}->submit_form
	(
		form_number => 1,
		fields      => 
		{
			form_submitted			=> 1,
			csrfKey 			=> $csrfkey,
			captcha_field			=> 1,
			username			=> $_[1],
			email_address			=> $_[3],
			password			=> $_[2],
			password_confirm		=> $_[2],
			'g-recaptcha-response'		=> $_[0],
			reg_admin_mails			=> 0,
			reg_agreed_terms		=> 0,
			reg_agreed_terms_checkbox	=> 1,
		}
	);

	if ($self->{_browser}->success)
	{
		if ($self->{_browser}->response()->decoded_content())
		{
			if (index($self->{_browser}->response()->decoded_content(),'fa-envelope') != -1) 
			{print "[+] User registred / ". $_[1] ." / ". $_[2] ." / ".$_[3]."\r\n" if $self->{_debug}; return 1;}

			elsif (index($self->{_browser}->response()->decoded_content(),'fa-lock') != -1) 
			{print "[-] Account needs to be approved / ". $_[1] ." / ". $_[2] ." / ".$_[3]."\r\n" if $self->{_debug}; return 2;}

			else{ if ($self->{_browser}->response()->decoded_content() =~ /ipsType_warning">(.*?)</)
			{die $1;} else { die 'Unknown error register';} }
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

#
# Public methods
#

sub new
{
	my $class = shift(@_);

	my $self = 
	{
		_domain 	=> shift,
		_antikey 	=> shift,
		_gkey		=> shift,
		_ua		=> 'Mozilla/5.0',
	};

	for (keys % { $self })
	{ $self->{$_} or croak "@{ [ $_ ] } is required."; }

	bless $self => $class;

	return $self;
}

sub debug
{
	my $self = shift(@_);

	$self->{_debug} = $_[0];
}

sub proxy
{
	my $self = shift(@_);

	$self->{_proxyhost} = $_[0];
	$self->{_proxyport} = $_[1];
}

sub ua
{
	my $self = shift(@_);

	$self->{_ua} = $_[0];
}

sub register
{
	my $self = shift(@_);

	my $captcha;
	my $task;
	my $gkey;
	my $res;

	$captcha = AntiCaptcha->new
	(
		$self->{_antikey},
	);

	$captcha->setopt({ type=>'NoCaptchaTaskProxyless', 
	websiteURL=>$self->{_domain}, websiteKey=>$self->{_gkey} });

	eval 
	{
		$task = $captcha->createtask();
		if ($task->{errorId} == 0)
		{
			$gkey  = $captcha->waittask(180, $task->{taskId});
			if ($gkey->{status} eq 'ready')
			{
				$res = $self->$_requestregister($gkey->{solution}->{gRecaptchaResponse}, $_[0], $_[1], $_[2]);
			}
			else
			{
				die 'Captcha solving timeout (waiting time > 180s)';
			}
		}
		else
		{
			die $task->{errorDescription};
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

InvisionForum::Register - Automatic register user on InvisionForum.

=head1 VERSION

version 1.00

=head1 SYNOPSIS

	use warnings;
	use strict;

	use InvisionForum::Register;

	sub main
	{
		my $invision;
		my $res;

		$invision = InvisionForum::Register->new
		(
			'https://domain.com',
			'anticaptchakey',
			'googlesitekey',
		);

		$invision->debug(1);

		$invision->proxy('host', port);

		$invision->ua('Mozilla/5.0');

		$res = $invision->register('username', 'password', 'email');

		if ($res)
		{
			print "Registred\n" if $res == 1;
			print "Waiting\n" if $res == 2;
		}
		else
		{
			# Error ...
		}
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

=item * register(USERNAME,PASSWORD,EMAIL)

Register user on board.

INPUT : USERNAME PASSWORD EMAIL

OUTPUT:

undef = error

1 = user full registred

2 = user waiting for to be approved by administrator

See String::Random module on CPAN to generate passwords and users name.

=back