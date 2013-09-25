requires 'perl', '5.008005';

requires 'Carp';
requires 'HTML::TreeBuilder';
requires 'HTTP::Request::Common';
requires 'JSON', 2;
requires 'LWP::UserAgent::Paranoid';

on test => sub {
  requires 'Test::More', '0.88';
};
