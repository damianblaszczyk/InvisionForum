package AntiCaptcha;

use warnings;
use strict;
use Carp;
use JSON::MaybeXS;

use WWW::Mechanize;
use Data::Dumper;

#
# Private methods
#

my $_request = sub
{
	my $self	= shift(@_);
	my $method 	= shift(@_);

	my $json;
	my $rcvit;

	$json = encode_json $_[0];

	$self->{_browser} = WWW::Mechanize->new
	(
		ssl_opts => 
		{
			verify_hostname => 0,
			SSL_verify_mode => 0,
		},
		timeout => 15,		
	);

	$self->{_browser}->add_header
	( 
		'content-type' => 'application/json',
	);

	$self->{_browser}->post
	(
		$self->{_url} . $method, 
		Content => $json
	);

	if ($self->{_browser}->success)
	{
		if ($self->{_browser}->response()->decoded_content())
		{
			$rcvit = decode_json $self->{_browser}->response()->decoded_content();
		}
		else
		{
			die "Decoding content problem";
		}
	}
	else
	{
		die "Request message problem";
	}

	print Dumper( \$rcvit ) if $self->{_dump};

	return $rcvit;
};

#
# Public methods
#

sub new
{
	my $class = shift(@_);

	my $self = 
	{
		_apikey => shift(@_),
		_url	=> 'http://api.anti-captcha.com',
	};

	for (keys % { $self })
	{ $self->{$_} or croak "@{ [ $_ ] } is required."; }

	bless $self => $class;

	return $self;
}

sub setdebug
{
	my $self = shift(@_);
	$self->{_dump} 	= $_[0];
}

sub setopt
{
	my $self = shift(@_);

	delete $self->{opt};

	for (keys % { $_[0] })
	{$self->{opt}->{$_} = $_[0]->{$_};}
}

sub createtask 
{
	my $self = shift(@_);

	my %sendit;

	%sendit =
	(
		clientKey	=> $self->{_apikey},
		task 		=> 
		{
			type 		=> $self->{_type},
			websiteURL	=> $self->{_domain},
			websiteKey	=> $self->{_keysite},
		},
	);

	for (keys % { $self->{opt} })
	{$sendit{task}{$_} = $self->{opt}->{$_};}

	$self->$_request('/createTask', \%sendit);
}

sub checktask
{
	my $self = shift(@_);

	my %sendit;

	%sendit =
	(
		clientKey	=> $self->{_apikey},
		taskId 		=> $_[0],
	);

	$self->$_request('/getTaskResult', \%sendit);
}

sub getbalance
{
	my $self = shift(@_);

	my %sendit;

	%sendit =
	(
		clientKey 	=> $self->{_apikey},
	);

	$self->$_request('/getBalance', \%sendit);
}

sub queuestats
{
	my $self = shift(@_);

	my %sendit;

	%sendit =
	(
		queueId		=> $_[0],
	);

	$self->$_request('/getQueueStats', \%sendit);	
}

sub reportIncorrectimagecaptcha
{
	my $self = shift(@_);

	my %sendit;

	%sendit =
	(
		clientKey	=> $self->{_apikey},
		taskId 		=> $_[0],
	);

	$self->$_request('/reportIncorrectImageCaptcha', \%sendit);	
}

sub reportincorrectrecaptcha
{
	my $self = shift(@_);

	my %sendit;

	%sendit =
	(
		clientKey	=> $self->{_apikey},
		taskId 		=> $_[0],
	);

	$self->$_request('/reportIncorrectRecaptcha', \%sendit);	
}

sub getspendingstats
{
	my $self = shift(@_);

	my %sendit;

	%sendit =
	(
		clientKey	=> $self->{_apikey},
	);

	for (keys % { $self->{opt} })
	{$sendit{$_} = $self->{opt}->{$_};}

	$self->$_request('/getSpendingStats', \%sendit);	
}

sub getappstats
{
	my $self = shift(@_);

	my %sendit;

	%sendit =
	(
		clientKey	=> $self->{_apikey},
	);

	for (keys % { $self->{opt} })
	{$sendit{$_} = $self->{opt}->{$_};}

	$self->$_request('/getAppStats', \%sendit);	
}

sub sendfunds
{
	my $self = shift(@_);

	my %sendit;

	%sendit =
	(
		clientKey	=> $self->{_apikey},
	);

	for (keys % { $self->{opt} })
	{$sendit{$_} = $self->{opt}->{$_};}

	$self->$_request('/sendFunds', \%sendit);	
}

sub waittask
{
	my $self = shift(@_);

	my $time;
	my $res;

	$time = 0;
	while ($time < $_[0])
	{
		$res = $self->checktask($_[1]);
		if ($res->{status} eq "processing")
		{
			$time+=5;
			sleep 5;
		}
		else
		{
			last;
		}
	}
	return $res;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

AntiCaptcha - Automatic solving captcha from many websites.

http://api.anti-captcha.com/

=head1 VERSION

version 1.00

=head1 SYNOPSIS

	use warnings;
	use strict;

	use AntiCaptcha;

	sub main
	{
		my $captcha;
		my $res;
		my $task;
		my $balance;

		$captcha = new AntiCaptcha
		(
			# Your API key
			"93079f5443ae3c7a8c8wb9gbw3deg09f",
		);

		# Print JSON response live in console
		$captcha->setdebug(1);

		#
		# Methods return hash with JSON parsed data
		#

		# Check Your balance
		$balance = $captcha->getbalance()->{balance};

		# Set param in request
		# More info on site with API documentation
		# setopt save param in request, if you use new setopt old params be deleted
		# clientKey is always in request, you don't declare in setopt
		$captcha->setopt({ type=>'NoCaptchaTaskProxyless', 
		websiteURL=>'https://domain.com', websiteKey=>'6Lc0SxgUAA2AANZc3armJOAlR-_KRLQZpQ8XWWMk' });

		# Create new task
		$res = $captcha->createtask();
		$task = $res->{taskId} if $res->{errorId} == 0;

		# Check task result
		$res = $captcha->checktask($task);

		# Return suitable time to upload new task
		# Param ID, 6 = Recaptcha Proxyless task
		# More info on site with API documentation
		$res = $captcha->queuestats(6);

		# Waiting for solved captcha
		# Max time in second to waiting and taskId
		$res = $captcha->waittask(180, $task);

		# Incorrect solved Recaptcha?
		# Report to vendor
		$res = $captcha->reportincorrectrecaptcha($task);

		# Incorrect solved image captcha?
		# Report to vendor
		$res = $captcha->reportincorrectimagecaptcha($task);

		# Grabs account spendings and task volumes statistics
		$captcha->setopt({ queue=>'English ImageToText' });
		$res = $captcha->getspendingstats();

		# This method retrieves daily statistics for your application
		$captcha->setopt({ softId=>'247' });
		$res = $captcha->getappstats();

		# Send funds to another account
		$captcha->setopt({ amount=>'1.00' });
		$res = $captcha->sendfunds();

		# Disable printing JSON in console
		$captcha->setdebug(0);	

		return 0;
	}

	main();

=head1 METHODS

=over 4

=item * setdebug(INT)

Print JSON response live in console. Very helpfull while debugging tool.

=item * setopt({HASH})

Set param in request. More info on site with API documentation. 
Setopt save param in request, if you use new setopt old params be deleted. 
clientKey is always in request, you don't declare in setopt.

L<http://anticaptcha.atlassian.net/wiki/spaces/API/pages/5079073/createTask+captcha+task+creating>

=item * createtask()

Create new task. 

Return hash reference with decoded JSON response.

=item * checktask(taskId)

Check task result. 

Return hash reference with decoded JSON response.

=item * queuestats(ID)

Return suitable time to upload new task:

	1 - standard ImageToText, English language
	2 - standard ImageToText, Russian language
	5 - Recaptcha NoCaptcha tasks
	6 - Recaptcha Proxyless task 
	7 - Funcaptcha
	10 - Funcaptcha Proxyless
	11 - Square Net Task
	12 - GeeTest Proxy-On
	13 - GeeTest Proxyless
	18 - Recaptcha V3 s0.3
	19 - Recaptcha V3 s0.7
	20 - Recaptcha V3 s0.9
	21 - hCaptcha Proxy-On
	22 - hCaptcha Proxyless

Return hash reference with decoded JSON response.

=item * waittask(SECONDS, taskId)

Waiting for solved captcha.
Max time in second to waiting and taskId.

Return hash reference with decoded JSON response.

=item * reportincorrectrecaptcha(taskId)

Incorrect solved Recaptcha?
Report to vendor.
Not all reports are accepted. In order to calculate your average fails rate with proper level of accuracy, 
minimum 100 of recaptcha tasks per account must be sent for recognition per 24 hours.

Return hash reference with decoded JSON response.

=item * reportincorrectimagecaptcha(taskId)

Incorrect solved image captcha?
Report to vendor.

Complaints are accepted only for image captchas. Your complaint will be checked by 5 workers, 4 of them must confirm it. 
Only then you get full refund. If you have less than 90% mistakes confirmation ratio, your reports will be ignored. 
Reports must be sent within 60 seconds after task completion. It is allowed to send only one report per task.
Why 90%? Your reports must be very precise and you must be 100% sure that they are correct. 
You can't just report every other captcha, you must code your software with 
strict testing standards and must be sure that target website does not detect you some other way.

Return hash reference with decoded JSON response.

=item * getbalance()

Check Your balance. 

Return hash reference with decoded JSON response.

=item * getspendingstats()

Grabs account spendings and task volumes statistics.

Return hash reference with decoded JSON response.

=item * getappstats()

This method retrieves daily statistics for your application.

Return hash reference with decoded JSON response.

=item * sendfunds()

Send funds to another account.
Your account must be enabled for this feature. Please contact support and explain why you need this.

Return hash reference with decoded JSON response.

=back