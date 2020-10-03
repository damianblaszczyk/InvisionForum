package InvisionForum::Users;

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

my $_printdebug = sub
{
	my $self = shift(@_);

	print 
		"[+] " . $self->{_searchlink} . "" .
		" Mined " . $_[0] . " users\r\n";
};

my $_cfdecode = sub
{
	my $self = shift(@_);

	my $k;
	my $i;
	my $email;

	if ($_[0] =~ m/data-cfemail="(.*?)"/)
	{
		$k = hex(substr($1,0,2));
		for($i=2 ; $i < length($1)-1 ; $i += 2)
		{
			$email .= chr(hex(substr($1,$i,2))^$k);
		}
	}
	$_[0] =~ s/<span.*?<\/span>/$email/sg;
	return $_[0];
};

my $_cleanuser = sub
{
	my $self = shift(@_);

	$_[0] = $self->$_cfdecode($_[0]) 
		if (index($_[0], 'data-cfemail') != -1);

	$_[0] = decode_entities( $_[0] );
	return $_[0];
};

my $_getuserlist = sub
{
	my $self = shift(@_);

	my @users;

	my $data;
	my $user;

	$self->{_browser}->get
	(
		$self->{_domain} . $self->{_searchlink} 
	);

	if ($self->{_browser}->success)
	{
		if ($self->{_browser}->response()->decoded_content())
		{
			$data = $self->{_browser}->response()->decoded_content();
			while ($data =~ m/<a href=.*?class="ipsType_break".*?>(.*?)<\/a>/gs)
			{
				$user = $1;
				push(@users, $self->$_cleanuser($user));
			}
			$self->$_printdebug(scalar(@users)) if $self->{_debug};
			return \@users;
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
		_domain		=> shift,
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

sub sparam
{
	my $self = shift(@_);

	$self->{_searchlink} = $_[0];
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

sub downloadusers
{
	my $self = shift(@_);

	my @param;

	my $users;

	eval 
	{
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
			. $self->{_proxyhost} . ":" 
			. $self->{_proxyport} . "/" 
		) if ($self->{_proxyhost} && $self->{_proxyport});

		$users = $self->$_getuserlist();			
		undef $self->{_browser};
	};
	if ($@)
	{
		warn "[-] " . $@ if $self->{_debug};
		return undef;
	}	
	else
	{
		return $users;
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

	use InvisionForum::Users;

	sub main
	{
		my $invision;
		my $users;
	
		$invision = InvisionForum::Users->new
		(
			'https://domain.com'
		);

		$invision->debug(1);

		$invision->proxy('host', port);

		$invision->ua('Mozilla/5.0');

		$invision->sparam('/search/?&type=core_members&page=1&joinedDate=any&group[3]=1');

		$users = $invision->downloadusers();

		for (my $i = 1; $i <= 10 ;)
		{
			$invision->sparam("/search/?&q=\@&type=core_members&page=" . $i . "&joinedDate=any&group[3]=1");
			$users = $invision->downloadusers();

			if ($users)
			{
				foreach (@{$users})
				{
					print "$_\r\n";
				}
				$i++;
			}
			else
			{
				# Error, don't increment page, try again...
			}
		}

		return 0;	
	}

	main ();

=head1 METHODS

=over 4

=item * debug(INT)

Set print messages debugging
Default is disable, You can disable by set 0

=item * proxy(HOST,PORT)

Set proxy every request, support only HTTP proxy, default is disable.

=item * ua(USERAGENT)

Define your useragent to request, default is Mozilla/5.0

=item * sparam(/search/..)

Define search parameters, you can define groups, phrase, etc. by search URL.
Go to https://domain.com/search/ and generate the parameter you need.
This param is OBLIGATORY!

=item * downloadusers()

Download users from page. Return array reference.
If script have problem with download users return value undef.

=back