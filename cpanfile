requires 'DateTime';
requires 'Email::Sender::Simple';
requires 'Mango';
requires 'Mojolicious';
requires 'Mojolicious::Plugin::PODRenderer';
requires 'Mojolicious::Plugin::RenderFile';
requires 'Mojolicious::Plugin::Util::RandomString';
requires 'Mojolicious::Static';

requires 'Moo';
requires 'Time::HiRes';
requires 'Try';
requires 'Data::UUID';
requires 'Template::Alloy';
requires 'JSON::XS', '< 3.0';
requires 'JSON';


# helpers for Mojo::IOLoop
requires 'EV', '>= 4';
requires 'IO::Socket::IP', '>= 0.16';
requires 'IO::Socket::SSL', '>= 1.75';

on 'test' => sub {
    requires 'Data::Dumper::Perltidy';
    requires 'Test::Exception';
    requires 'Devel::Cover';
};


