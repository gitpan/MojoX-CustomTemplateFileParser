requires 'perl', '5.010';

requires 'Mojo::Base', '5.00';
requires 'Path::Tiny', '0.050';

on test => sub {
    requires 'Test::More', '0.96';
    requires 'Test::Deep', '0.110';
    requires 'Data::Dumper', '2.130';
};
