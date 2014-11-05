package MojoX::CustomTemplateFileParser;

use strict;
use warnings;
use 5.10.1;
our $VERSION = '0.03';

use Mojo::Base -base;
use Path::Tiny();
use Storable qw/dclone/;

has path => undef;
has structure => sub { { } };

sub flatten {
    my $self = shift;
    my $baseurl = $self->_get_baseurl;
    my $filename = $self->_get_filename;

    if(!scalar keys %{ $self->structure }) {
        $self->parse;
    }
    my $info = $self->structure;

    my @parsed = join "\n" => @{ $info->{'head_lines'} };

    TEST:
    foreach my $test (@{ $info->{'tests'} }) {
        next TEST if !scalar @{ $test->{'lines_template'} };

        my $expected_var = sprintf '$expected_%s' => $test->{'test_name'};

        push @parsed => "#** test from $filename, line $test->{'test_start_line'}" . ($test->{'loop_variable'} ? ", loop: $test->{'loop_variable'}" : '');
        push @parsed => sprintf 'my %s = qq{ %s };' => $expected_var, join "\n" => @{ $test->{'lines_expected'} };

        push @parsed => sprintf q{get '/%s' => '%s';} => $test->{'test_name'}, $test->{'test_name'};
        push @parsed => sprintf q{$test->get_ok('/%s')->status_is(200)->trimmed_content_is(%s, '%s');}
                                => $test->{'test_name'}, $expected_var, sprintf qq{Matched trimmed content in $filename, line $test->{'test_start_line'}%s}
                                                                                => $test->{'loop_variable'} ? ", loop: $test->{'loop_variable'}" : '';
    }

    push @parsed => 'done_testing();';
    push @parsed => '__DATA__';


    foreach my $test (@{ $info->{'tests'} }) {
        next TEST if !scalar @{ $test->{'lines_template'} };

        push @parsed => sprintf '@@ %s.html.ep' => $test->{'test_name'};
        push @parsed => join "\n" => @{ $test->{'lines_template'} };
    }

    return join ("\n\n" => @parsed) . "\n";
}

sub parse {
    my $self = shift;
    my $baseurl = $self->_get_baseurl;
    my @lines = split /\n/ => Path::Tiny::path($self->path)->slurp;

    # matches ==test== ==no test== ==test loop(a thing or two)== ==test example ==test 1== ==test example 2==
    my $test_start = qr/==(?:(NO) )?TEST(?: loop\(([^)]+)\))?(?: EXAMPLE)?(?: (\d+))?==/i;
    my $template_separator = '--t--';
    my $expected_separator = '--e--';

    my $environment = 'head';

    my $info = {
        head_lines => [],
        tests      => []
    };
    my $test = {};

    my $row = 0;
    my $testcount = 0;

    LINE:
    foreach my $line (@lines) {
        ++$row;

        if($environment eq 'head') {
            if($line =~ $test_start) {
                my $skipit = $1;
                $test->{'loop'} = defined $2 ? [ split / / => $2 ] : [];
                my $testnumber = $3;

                $test = $self->_reset_test();

                if(defined $skipit && $skipit eq lc 'no') {
                    $test->{'skip'} = $skipit;
                }

                $test->{'test_number'} = $testnumber;
                ++$testcount;

                push @{ $info->{'head_lines'} } => '';
                $test->{'test_start_line'} = $row;
                $test->{'test_number'} = $testcount;
                $test->{'test_name'} = sprintf '%s_%s' => $baseurl, $testcount;
                $environment = 'beginning';

                next LINE;
            }
            push @{ $info->{'head_lines'} } => $line;
            next LINE;
        }
        if($environment eq 'beginning') {
            if($line eq $template_separator) {
                push @{ $test->{'lines_before'} } => '';
                $environment = 'template';
                next LINE;
            }
            push @{ $test->{'lines_before'} } => $line;
            next LINE;
        }
        if($environment eq 'template') {
            if($line eq $template_separator) {
                # No need to push empty line to the template
                $environment = 'between';
                next LINE;
            }
            # If we have no template lines, don't push empty lines.
            # This way we can avoid empty templates, meaning we can leave empty test blocks in the
            # source files without messing up the tests.
            push @{ $test->{'lines_template'} } => $line if scalar @{ $test->{'lines_template'} } || $line !~ m{^\s*$};
            next LINE;
        }
        if($environment eq 'between') {
            if($line eq $expected_separator) {
                push @{ $test->{'lines_between'} } => '';
                $environment = 'expected';
                next LINE;
            }
            push @{ $test->{'lines_expected'} } => $line;
            next LINE;
        }
        if($environment eq 'expected') {
            if($line eq $expected_separator) {
                $environment = 'ending';
                next LINE;
            }
            push @{ $test->{'lines_expected'} } => $line;
            next LINE;
        }
        if($environment eq 'ending') {
            if($line =~ $test_start) {
                push @{ $test->{'lines_after'} } => '';

                $self->_add_test($info, $test);

                $test = $self->_reset_test();
                my $skipit = $1;
                if(defined $skipit && $skipit eq lc 'no') {
                    $test->{'skip'} = 1;
                }
                $test->{'loop'} = defined $2 ? [ split / / => $2 ] : [];
                ++$testcount;
                $test->{'test_start_line'} = $row;
                $test->{'test_number'} = $testcount;
                $test->{'test_name'} = sprintf '%s_%s' => $baseurl, $testcount;
                $environment = 'beginning';

                next LINE;
            }
            push @{ $test->{'lines_after'} } => $line;
            next LINE;
        }
    }
    push @{ $info->{'tests'} } => $test if scalar @{ $test->{'lines_template'} };
    $self->_add_test($info, $test);

    $self->structure($info);

    return $self;
}

sub _add_test {
    my $self = shift;
    my $info = shift;
    my $test = shift;
    use Data::Dumper 'Dumper';

    #* Nothing to test
    return if !scalar @{ $test->{'lines_template'} } || $test->{'skip'};

    #* No loop, just add it
    if(!scalar @{ $test->{'loop'} }) {
        push @{ $info->{'tests'} } => $test;
        return;
    }

    foreach my $var (@{ $test->{'loop'} }) {
        my $copy = dclone $test;

        map { $_ =~ s{\[var\]}{$var}g } @{ $copy->{'lines_template'} };
        map { $_ =~ s{\[var\]}{$var}g } @{ $copy->{'lines_expected'} };
        $copy->{'loop_variable'} = $var;
        push @{ $info->{'tests'} } => $copy;
    }
    return;



}

sub _reset_test {
    my $self = shift;
    return {
        lines_before => [],
        lines_template => [],
        lines_after => [],
        lines_between => [],
        lines_expected => [],
        test_number => undef,
        test_start_line => undef,
        test_name => undef,
        loop => [],
        loop_variable => undef,
    };
}

sub _get_filename {
    return Path::Tiny::path(shift->path)->basename;
}

sub _get_baseurl {
    my $self = shift;
    my $filename = $self->_get_filename;
    (my $baseurl = $filename) =~ s{^([^\.]+)\..*}{$1}; # remove suffix
    $baseurl =~ s{-}{_};
    return $baseurl;
}

1;
__END__

=encoding utf-8

=head1 NAME

MojoX::CustomTemplateFileParser - Parses a custom Mojo template file format

=head1 SYNOPSIS

  use MojoX::CustomTemplateFileParser;

  my $content = MojoX::CustomTemplateFileParser->new(path => '/path/to/file.mojo')->parse->flatten;

  print $content;

=head1 STATUS

Unstable.

=head1 DESCRIPTION

MojoX::CustomTemplateFileParser parses files containing L<Mojo::Templates|Mojo::Template> mixed with the expected rendering.

The parsing creates a data structure that also can be dumped into a string ready to be put in a L<Test::More> file.

Its purpose is to facilitate development of tag helpers.

=head2 Options

B<C<path>>

The only argument given to the constructor is the path to the file that should be parsed.

=head2 Methods

B<C<$self-E<gt>parse>>

Parses the file given in C<path>. After parsing the structure is available in C<$self-E<gt>structure>.

B<C<$self-E<gt>flatten>>

Returns a string that is suitable to put in a L<Test::More> test file.

=head1 Example

Given a file (C<metacpan-1.mojo>) that looks like this:


    # Code here

    ==test==
    --t--
        %= link_to 'MetaCPAN', 'http://www.metacpan.org/'
    --t--
    --e--
        <a href="http://www.metacpan.org/">MetaCPAN</a>
    --e--

    ==test loop(first name)==
    --t--
        %= text_field username => placeholder => '[var]'
    --t--
    --e--
        <input name="username" placeholder="[var]" type="text" />
    --e--

    ==no test==
    --t--
        %= text_field username => placeholder => 'Not tested'
    --t--
    --e--
        <input name="username" placeholder="Not tested" type="text" />
    --e--

    ==test==
    --t--

    --t--

    --e--

    --e--

C<loop(first name)> on the second test means there is one test generated where C<[var]> is replaced with C<first> and one where it is replaced with C<name>.

C<no test> on the third test means it is skipped.

Running C<$self-E<gt>parse> will fill C<$self-E<gt>structure> with:

    {
        head_lines => ['', '# Code here', '', '' ],
        tests => [
            {
                lines_after => ['', ''],
                lines_before => [''],
                lines_between => [''],
                lines_expected => [ '    <a href="http://www.metacpan.org/">MetaCPAN</a>' ],
                lines_template => [ "    %= link_to 'MetaCPAN', 'http://www.metacpan.org/'" ],
                loop => [],
                loop_variable => undef,
                test_name => 'test_1_1',
                test_number => 1,
                test_start_line => 4,
            },
            {
                lines_after => ['', ''],
                lines_before => [''],
                lines_between => [''],
                lines_expected => [ '    <input name="username" placeholder="first" type="text" />' ],
                lines_template => [ "    %= text_field username => placeholder => 'first'" ],
                loop => [ 'first', 'name' ],
                loop_variable => 'first',
                test_name => 'test_1_2',
                test_number => 2,
                test_start_line => 12,
            },
            {
                lines_after => ['', ''],
                lines_before => [''],
                lines_between => [''],
                lines_expected => [ '    <input name="username" placeholder="name" type="text" />' ],
                lines_template => [ "    %= text_field username => placeholder => 'name'" ],
                loop => [ 'first', 'name' ],
                loop_variable => 'name',
                test_name => 'test_1_2',
                test_number => 2,
                test_start_line => 12,
            }
        ]
    }

And C<$self-E<gt>flatten> returns:

    # Code here

    #** test from test-1.mojo, line 4

    my $expected_test_1_1 = qq{     <a href="http://www.metacpan.org/">MetaCPAN</a> };

    get '/test_1_1' => 'test_1_1';

    $test->get_ok('/test_1_1')->status_is(200)->trimmed_content_is($expected_test_1_1, 'Matched trimmed content in test-1.mojo, line 4');

    #** test from test-1.mojo, line 12, loop: first

    my $expected_test_1_2 = qq{     <input name="username" placeholder="first" type="text" /> };

    get '/test_1_2' => 'test_1_2';

    $test->get_ok('/test_1_2')->status_is(200)->trimmed_content_is($expected_test_1_2, 'Matched trimmed content in test-1.mojo, line 12, loop: first');

    #** test from test-1.mojo, line 12, loop: name

    my $expected_test_1_2 = qq{     <input name="username" placeholder="name" type="text" /> };

    get '/test_1_2' => 'test_1_2';

    $test->get_ok('/test_1_2')->status_is(200)->trimmed_content_is($expected_test_1_2, 'Matched trimmed content in test-1.mojo, line 12, loop: name');

    done_testing();

    __DATA__

    @@ test_1_1.html.ep

        %= link_to 'MetaCPAN', 'http://www.metacpan.org/'

    @@ test_1_2.html.ep

        %= text_field username => placeholder => 'first'

    @@ test_1_2.html.ep

        %= text_field username => placeholder => 'name'


The easiest way to is it is with L<Dist::Zilla::Plugin::Test::CreateFromMojoTemplates>.

=head1 AUTHOR

Erik Carlsson E<lt>info@code301.comE<gt>

=head1 COPYRIGHT

Copyright 2014- Erik Carlsson

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
