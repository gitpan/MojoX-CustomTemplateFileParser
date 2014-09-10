requires 'perl', '5.14.0';

requires 'MooseX::Object::Pluggable', '0.0013';
requires 'Moose', '2.12',
requires 'Path::Tiny', '0.050';
requires 'Storable', '2.24';
requires 'HTML::Entities', '3.65';

on test => sub {
    requires 'Test::More', '0.96';
    requires 'Test::Deep', '0.110';
    requires 'Data::Dump::Streamer', '2.37';
};

on build => sub {
    requires 'Test::NoTabs', '1.3';
    requires 'Test::EOL', '1.5';
    requires 'Test::Pod', '1.45';
}

