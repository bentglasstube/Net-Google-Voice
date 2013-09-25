package Net::Google::Voice::Call;

use strict;
use warnings;

use base 'Net::Google::Voice::Item';

sub new_from_html {
  my ($class, $gv, $root) = @_;

  my $self = $class->SUPER::new_from_html($gv, $root);

  if ($self->{table}->look_down(class => 'gc-message-icon-0')) {
    $self->{type} = 'missed';
  } elsif ($self->{table}->look_down(class => 'gc-message-icon-1')) {
    $self->{type} = 'received';
  } elsif ($self->{table}->look_down(class => 'gc-message-icon-4')) {
    $self->{type} = 'recorded';
  } elsif ($self->{table}->look_down(class => 'gc-message-icon-15')) {
    $self->{type} = 'placed';
  }

  $self;
}

sub type { shift->{type} }

sub download {
  my ($self) = @_;

  # TODO check for voicemail

  my $r = $self->{gv}->_get('https://www.google.com/voice/media/send_voicemail/' . $self->id);
  return $r->decoded_content();
}

1;
