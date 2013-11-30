requires 'DateTime';
requires 'Email::Sender::Simple';
requires 'Mango';
requires 'Mojo';
requires 'Mojolicious::Plugin::PODRenderer';
requires 'Mojolicious::Plugin::RenderFile';
requires 'Mojolicious::Plugin::Util::RandomString';
requires 'Moo';
requires 'Time::HiRes';
requires 'Try';

on 'test' => sub {
    requires 'Data::Dumper::Perltidy';
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
