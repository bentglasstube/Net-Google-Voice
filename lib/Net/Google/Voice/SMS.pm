package Net::Google::Voice::SMS;

use strict;
use warnings;

use base 'Net::Google::Voice::Item';

sub new_from_html {
  my ($class, $gv, $root) = @_;

  my $self = $class->SUPER::new_from_html($gv, $root);

  $self->{messages} = [];
  my @rows = $self->{table}->look_down(class => 'gc-message-sms-row');
  foreach my $row (@rows) {

    # TODO make single message object
    push @{ $self->{messages} }, {
      type => (
        $row->look_down(class => 'gc-message-sms-from')->as_text eq 'Me: '
        ? 'outgoing'
        : 'incoming'
      ),
      text => $row->look_down(class => 'gc-message-sms-text')->as_text,
      time => $row->look_down(class => 'gc-message-sms-time')->as_text,
      };
  }

  $self;
}

sub messages {
  my ($self, $n) = @_;

  if (@_ == 1) {
    return wantarray ? @{ $self->{messages} } : $self->{messages};
  } else {
    return $self->{messages}[$n];
  }
}

sub reply {
  my ($self, $message) = @_;

  my $phone = 'bluh';    # TODO get contact phone number
  $self->{gv}->send_sms($phone, $message, $self->id);
}

1;
