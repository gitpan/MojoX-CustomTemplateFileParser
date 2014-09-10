use strict;
use Test::More;
use MojoX::CustomTemplateFileParser;

my $parser = MojoX::CustomTemplateFileParser->new(path => 'corpus/test-1.mojo', output => ['Pod']);

my $expected = q{
    %= link_to 'MetaCPAN', 'http://www.metacpan.org/'

    <a href="http://www.metacpan.org/">MetaCPAN</a>

};

is $parser->to_pod(1), $expected, 'Creates correct pod';


done_testing;
