requires 'DateTime';
requires 'Email::Sender::Simple';
requires 'Mango';
requires 'Mojolicious';
requires 'Mojolicious::Plugin::PODRenderer';
requires 'Mojolicious::Plugin::RenderFile';
requires 'Mojolicious::Plugin::Util::RandomString';
requires 'Moo';
requires 'Time::HiRes';
requires 'Try';
requires 'Data::UUID';

# helpers for Mojo::IOLoop
requires 'EV', '>= 4';
requires 'IO::Socket::IP', '>= 0.16';
requires 'IO::Socket::SSL', '>= 1.75';

on 'test' => sub {
    requires 'Data::Dumper::Perltidy';
    requires 'Test::Exception';
    requires 'Devel::Cover';
};


# PDF::Grid requires
requires 'Moo';
requires 'Clone';
requires 'Hash::Merge';
requires 'JSON';
requires 'List::AllUtils';
requires 'PDF::API2';
requires 'Try';
requires 'XML::Parser';
requires 'YAML';
requires 'YAML::Syck';


