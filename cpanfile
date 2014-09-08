requires 'perl', '5.14.0';

requires 'Mojolicious', '5.00';
requires 'Path::Tiny', '0.050';
requires 'Storable', '2.24';

on test => sub {
    requires 'Test::More', '0.96';
    requires 'Test::Deep', '0.110';
    requires 'Data::Dump::Streamer', '2.37';
};


