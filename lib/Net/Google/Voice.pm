package Net::Google::Voice;

use 5.008_005;
use strict;
use warnings;

our $VERSION = '0.01';

use Carp 'croak';
use HTML::TreeBuilder;
use HTTP::Request::Common;
use JSON 2;
use LWP::UserAgent::Paranoid;

use Net::Google::Voice::Call;
use Net::Google::Voice::SMS;

sub _request {
  my ($self, $request) = @_;

  $request->header(Authorization => 'GoogleLogin auth=' . $self->_login);

  my $response = $self->{ua}->request($request);

  croak 'Request failed: ' . $response->status_line
    unless $response->is_success;

  $response;
}

sub _post {
  my ($self, $url, $param) = @_;

  $param->{_rnr_se} = $self->_rnrse;

  $self->_request(HTTP::Request::Common::POST($url, $param));
}

sub _get {
  my ($self, $url) = @_;

  $self->_request(HTTP::Request::Common::GET($url));
}

sub _login {
  my ($self) = @_;

  return $self->{auth} if $self->{auth};

  my $r = $self->{ua}->post(
    'https://www.google.com/accounts/ClientLogin', {
      accountType => 'GOOGLE',
      Email       => $self->{email},
      Passwd      => $self->{password},
      service     => 'grandcentral',
      source      => "AlanBerndt-NetGoogleVoice-$VERSION",
    },
  );

  croak 'Request failed: ' . $r->status_line unless $r->is_success;

  if ($r->decoded_content =~ /Auth=([\w-]+)/) {
    $self->{auth} = $1;
  } else {
    croak 'Unable to find auth in response';
  }

  $self->{auth};
}

sub _rnrse {
  my ($self) = @_;

  return $self->{rnrse} if $self->{rnrse};

  my $r = $self->_request(
    HTTP::Request::Common::GET('https://www.google.com/voice/b/0'));

  if ($r->decoded_content =~ m{'_rnr_se': '(.*?)',}) {
    $self->{rnrse} = $1;
  } elsif ($r->decoded_content =~ m{<div class="gc_notice">(.*?)</div>}) {
    $self->{rnrse} = $1;
  } else {
    croak 'Could not find _rnr_se';
  }

  $self->{rnrse};
}

sub _get_items {
  my ($self, $url, $page) = @_;

  $page ||= 1;

  my $r = $self->_request(HTTP::Request::Common::GET("$url?page=p$page"));

  $r->decoded_content =~ m{<html><!\[CDATA\[(.*?)\]\]></html>}sm or return;
  my $t = HTML::TreeBuilder->new_from_content($1);

  my @messages =
    $t->look_down(_tag => 'div', class => qr/(?:^| )gc-message(?: |$)/);

  my @items = ();

  foreach my $message (@messages) {
    if ($message->attr('class') =~ /(?:^| )gc-message-sms(?: |$)/) {
      push @items, Net::Google::Voice::SMS->new_from_html($self, $message);
    } else {
      push @items, Net::Google::Voice::Call->new_from_html($self, $message);
    }
  }

  wantarray ? @items : \@items;
}

my $AGENT = join ' ', (
  'Mozilla/5.0 (Linux x86_64)',
  'AppleWebKit/537.36 (KHTML, like Gecko)',
  'Chrome/29.0.1547.76 Safari/537.36',
  );

sub new {
  my ($class, $email, $password) = @_;

  bless {
    email    => $email,
    password => $password,
    ua       => LWP::UserAgent->new(
      agent      => $AGENT,
      cookie_jar => {},
    ),
  }, $class;

  # TODO attempt login right away ?
}

my @labels = qw(
  all
  inbox
  missed
  placed
  received
  recorded
  sms
  spam
  starred
  trash
  voicemail
);

for my $label (@labels) {
  no strict 'refs';
  *{ __PACKAGE__ . '::' . $label } = sub {
    shift->_get_items("https://www.google.com/voice/b/0/inbox/recent/$label/",
      @_);
  };
}

sub settings {
  my ($self) = @_;

  my $r = $self->_get('https://www.google.com/voice/b/0/settings/tab/groups');

  if ($r->decoded_content =~ m{<json><!\[CDATA\[(.*?)\]\]></json>}) {
    my $json = decode_json($1);

    return $json;    # TODO make settings object
  } else {
    return undef;
  }
}

# TODO move to phone object

sub call {
  my ($self, $origin, $dest, $type) = @_;

  my $r = $self->_post(
    'https://www.google.com/voice/b/0/call/connect', {
      outgoingNumber   => $dest,
      forwardingNumber => $origin,
      subscriberNumber => 'undefined',
      phoneType        => $type,
      remember         => 0,
    });

  undef;
}

sub cancel {
  my ($self) = @_;

  my $r = $self->_post(
    'https://www.google.com/voice/b/0/call/cancel', {
      outgoingNumber   => 'undefined',
      forwardingNumber => 'undefined',
      cancelType       => 'C2C',
    });

  undef;
}

sub _enable {
  my ($self, $id, $enable) = @_;

  my $r = $self->_post(
    'https://www.google.com/voice/b/0/settings/editDefaultForwarding/', {
      enabled => ($enable ? 1 : 0),
      phoneId => $id,
    });

  undef;
}

sub enable_phone {
  my ($self, $id) = @_;
  $self->_enable($id, 1);
}

sub disable_phone {
  my ($self, $id) = @_;
  $self->_enable($id, 0);
}

# END phone object

# TODO move to settings object

sub do_not_disturb {
  my ($self, $dnd) = @_;

  my $r = $self->_post(
    'https://www.google.com/voice/b/0/settings/editGeneralSettings/',
    { doNotDisturb => ($dnd ? 1 : 0) });

  undef;    # TODO return current setting
}

sub announce {
  my ($self, $announce) = @_;

  my $r = $self->_post(
    'https://www.google.com/voice/b/0/settings/editGeneralSettings/',
    { directConnect => ($announce ? 1 : 0) });

  undef;    # TODO return current setting
}

sub greetings {
  my ($self) = @_;

  # TODO get greetings list
  # $self->settings()->greetings();
  undef;
}

# END settings object

# TODO move to greeting object ?

sub greeting {
  my ($self, $id) = @_;

  my $r = $self->_post(
    'https://www.google.com/voice/b/0/settings/editGeneralSettings/',
    { greetingId => $id });

  undef;    # TODO return current setting
}

# END greeting object

sub send_sms {
  my ($self, $dest, $message, $id) = @_;

  $id ||= '';

  my $r = $self->_post(
    'https://www.google.com/voice/b/0/sms/send/', {
      id             => $id,
      phoneNumber    => $dest,
      conversaiontId => $id,
      text           => $message,
    });

  undef;    # TODO parse result
}

1;

__END__

=encoding utf-8

=head1 NAME

Net::Google::Voice - Unofficial Google Voice API

=head1 SYNOPSIS

  use Net::Google::Voice;

  my $gv = Net::Google::Voice->new($email, $password);
  my @inbox = $gv->inbox();
  my @unread = grep { not $_->read } @inbox;

  say 'SMS from ' . $_->name for $gv->sms;
  say 'Missed call from ' . $_->name for $gv->missed;

=head1 DESCRIPTION

Net::Google::Voice is an unofficial API for accessing your Google Voice SMS and
call history.

=head1 AUTHOR

Alan Berndt E<lt>alan@eatabrick.orgE<gt>

=head1 COPYRIGHT

Copyright 2013 - Alan Berndt

=head1 LICENSE

This library is free software; you can redistribute it under the terms of the
MIT license.

=cut
