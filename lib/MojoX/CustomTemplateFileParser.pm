package MojoX::CustomTemplateFileParser;

use strict;
use warnings;
use 5.10.1;
our $VERSION = '0.01';

use Mojo::Base -base;
use Path::Tiny();

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

    my $testcount = 0;
    foreach my $test (@{ $info->{'tests'} }) {
        ++$testcount;
        my $expected_var = sprintf '$expected_%s' => $testcount;
        push @parsed => sprintf 'my %s = qq{ %s };' => $expected_var, join "\n" => @{ $test->{'lines_expected'} };

        push @parsed => sprintf q{get '/%s' => '%s';} => $test->{'test_name'}, $test->{'test_name'};
        push @parsed => sprintf q{$test->get_ok('/%s')->status_is(200)->trimmed_content_is(%s, '%s');}
                                => $test->{'test_name'}, $expected_var, qq{Matched trimmed content in $filename, line $test->{'test_start_line'}};
    }

    push @parsed => 'done_testing();';
    push @parsed => '__DATA__';

    foreach my $test (@{ $info->{'tests'} }) {
        push @parsed => sprintf '@@ %s.html.ep' => $test->{'test_name'};
        push @parsed => join "\n" => @{ $test->{'lines_template'} };
    }

    return join ("\n\n" => @parsed) . "\n";
}

sub parse {
    my $self = shift;
    my $baseurl = $self->_get_baseurl;
    my @lines = split /\n/ => Path::Tiny::path($self->path)->slurp;

    my $test_start = qr/==TEST(?: EXAMPLE)?(?: (\d+))?==/i;
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
                $test = $self->_reset_test();
                $test->{'test_number'} = $1;
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
            push @{ $test->{'lines_template'} } => $line;
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
                # No need to push empty line to the template
                $environment = 'ending';
                next LINE;
            }
            push @{ $test->{'lines_expected'} } => $line;
            next LINE;
        }
        if($environment eq 'ending') {
            if($line =~ $test_start) {
                push @{ $test->{'lines_after'} } => '';
                push @{ $info->{'tests'} } => $test;
                $test = $self->_reset_test();
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
    push @{ $info->{'tests'} } => $test;

    $self->structure($info);

    return $self;
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

MojoX::CustomTemplateFileParser parses files containing L<Mojo::Template>s mixed with the expected rendering.

The parsing creates a data structure that also can be dumped into a string ready to be put in a L<Test::More> file.

It's purpose is to facilitate development of tag helpers.

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

    ==test==
    --t--
    %= text_field username => placeholder => 'Enter name'
    --t--
    --e--
    <input name="username" placeholder="Enter name" type="text" />
    --e--

Running C<$self-E<gt>parse> will fill C<$self-E<gt>structure> with:

    {
        head_lines => ['',
                       '# Code here',
                       '',
                       ''
                      ],
        tests => [
                    {
                        test_number => 1,
                        test_name => 'metacpan_1_1',
                        test_start_line => 4,
                        lines_before => [''],
                        lines_template => [" %= link_to 'MetaCPAN', 'http://www.metacpan.org/" ],
                        lines_between => [''],
                        lines_expected => [ '<a href="http://www.metacpan.org/">MetaCPAN</a>' ],
                        lines_after => ['',''],
                    },
                    {
                       test_number => 2,
                       test_name => 'metacpan_1_2',
                       test_start_line => 12,
                       lines_before => [''],
                       lines_template => [ "%= text_field username => placeholder => 'Enter name'"" ],
                       lines_between => [''],
                       lines_expected => ['<input name="username" placeholder="Enter name" type="text" /> '],
                       lines_after => [],
                    }
                ],
        };

And C<$self-E<gt>flatten> returns:

    # Code here

    my $expected_1 = qq{ <a href="http://www.metacpan.org/">MetaCPAN</a> };

    get '/metacpan_1_1' => 'metacpan_1_1';

    $test->get_ok('/metacpan_1_1')->status_is(200)->trimmed_content_is($expected_1, 'Matched trimmed content in metacpan-1.mojo, line 4');

    my $expected_2 = qq{ <input name="username" placeholder="Enter name" type="text" /> };

    get '/metacpan_1_2' => 'metacpan_1_2';

    $test->get_ok('/metacpan_1_2')->status_is(200)->trimmed_content_is($expected_2, 'Matched trimmed content in metacpan-1.mojo, line 12');

    done_testing();

    __DATA__

    @@ metacpan_1_1.html.ep

    %= link_to 'MetaCPAN', 'http://www.metacpan.org/'

    @@ metacpan_1_2.html.ep

    %= text_field username => placeholder => 'Enter name'

And then all that remains is putting in a header. See L<Dist::Zilla::Plugin::Test::CreateFromMojoTemplates>.

=head1 AUTHOR

Erik Carlsson E<lt>info@code301.comE<gt>

=head1 COPYRIGHT

Copyright 2014- Erik Carlsson

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
