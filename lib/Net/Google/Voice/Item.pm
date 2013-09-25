package Net::Google::Voice::Item;

use strict;
use warnings;

sub new {
  my ($class, $gv, %data) = @_;
  bless { gv => $gv, %data }, $class;
}

sub new_from_html {
  my ($class, $gv, $root) = @_;

  my %data = ();

  $data{id}   = $root->attr('id');
  $data{read} = $root->attr('class') =~ /(?:^| )gc-message-read(?: |$)/;

  $data{table} = $root->look_down(class => 'gc-message-tbl');

  $data{name} = $data{table}->look_down(class => 'gc-message-name')->as_text;
  $data{time} = $data{table}->look_down(class => 'gc-message-time')->as_text;

  if (my $a = $data{table}->look_down(class => 'gc-under gc-message-name-link')) {
    $data{name} = $a->as_text;
  } else {
    my $name = $data{table}->look_down(class => 'gc-message-name');
    $data{name} = $name->look_down(class => 'gc-nobold')->as_text;
  }

  $class->new($gv, %data);
}

for my $m (qw(id read name time)) {
  no strict 'refs';
  *{ __PACKAGE__ . '::' . $m } = sub { shift->{$m} };
}

sub _process {
  my ($self, $location, $tag, $value) = @_;

  my $r = $self->{gv}->_post(
    'https://www.google.com/voice/b/0/inbox/' . $location . '/', {
      messages => $self->id,
      $tag     => $value,
    });

  return;
}

sub mark_read   { shift->_process('mark',            read    => 1) }
sub mark_unread { shift->_process('mark',            read    => 0) }
sub star        { shift->_process('star',            star    => 1) }
sub unstar      { shift->_process('star',            star    => 0) }
sub archive     { shift->_process('archiveMessages', archive => 1) }
sub unarchive   { shift->_process('archiveMessages', archive => 0) }
sub delete      { shift->_process('deleteMessages',  trash   => 1) }
sub undelete    { shift->_process('deleteMessages',  trash   => 0) }
sub spam        { shift->_process('spam',            spam    => 1) }
sub not_spam    { shift->_process('spam',            spam    => 0) }

# N.B. undelete apparently uses trash => 1 from inspecting web requests
# Investigate if this is needed.

1;
