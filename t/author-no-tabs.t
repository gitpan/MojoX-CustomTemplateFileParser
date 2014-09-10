
BEGIN {
  unless ($ENV{AUTHOR_TESTING}) {
    require Test::More;
    Test::More::plan(skip_all => 'these tests are for testing by the author');
  }
}

use strict;
use warnings;

# this test was generated with Dist::Zilla::Plugin::Test::NoTabs 0.09

use Test::More 0.88;
use Test::NoTabs;

my @files = (
    'lib/MojoX/CustomTemplateFileParser.pm',
    'lib/MojoX/CustomTemplateFileParser/Plugin/To/Html.pm',
    'lib/MojoX/CustomTemplateFileParser/Plugin/To/Pod.pm',
    'lib/MojoX/CustomTemplateFileParser/Plugin/To/Test.pm',
    't/1-structure.t',
    't/2-plugin-totest.t',
    't/3-plugin-topod.t',
    't/4-plugin-tohtml.t'
);

notabs_ok($_) foreach @files;
done_testing;
