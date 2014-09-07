use strict;
use Test::More;
use Test::Deep;
use Data::Dumper 'Dumper';
use MojoX::CustomTemplateFileParser;

my $found = MojoX::CustomTemplateFileParser->new(path => 'corpus/test-1.mojo')->parse->structure;

my $expected = {
        head_lines => ['',
                       '# Code here',
                       '',
                       ''
                      ],
        tests => [
                    {
                       test_number => 1,
                       test_name => 'test_1_1',
                       test_start_line => 4,
                       lines_before => [''],
                       lines_template => [ "%= link_to 'MetaCPAN', 'http://www.metacpan.org/'" ],
                       lines_between => [''],
                       lines_expected => [ '<a href="http://www.metacpan.org/">MetaCPAN</a>' ],
                       lines_after => ['',''],
                    },
                    {
                       test_number => 2,
                       test_name => 'test_1_2',
                       test_start_line => 12,
                       lines_before => [''],
                       lines_template => [ "%= text_field username => placeholder => 'Enter name'" ],
                       lines_between => [''],
                       lines_expected => ['<input name="username" placeholder="Enter name" type="text" />' ],
                       lines_after => ['', ''],
                    }
                ],
        };

cmp_deeply($found, $expected, "Parsed correctly") || warn Dumper $found;

done_testing;
