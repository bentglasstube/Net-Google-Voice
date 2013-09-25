package Net::Google::Voice::Settings;

use strict;
use warnings;

sub new {
  my ($class, $gv, $json) = @_;

  my $self = $json->{settings};
  $self->{gv} = $gv;

  bless $self, $class;
}

1;
