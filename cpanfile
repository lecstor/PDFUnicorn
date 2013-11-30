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