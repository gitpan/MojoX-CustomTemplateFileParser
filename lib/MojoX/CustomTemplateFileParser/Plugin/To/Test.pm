package MojoX::CustomTemplateFileParser::Plugin::To::Test;

use strict;
use warnings;
use 5.10.1;
our $VERSION = '0.10';

use Moose::Role;

sub to_test {
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

        my $expected_var = sprintf '$expected_%s%s' => $test->{'test_name'}, ($test->{'loop_variable'} ? "_$test->{'loop_variable'}" : '');

        push @parsed => "\n#** test from $filename, line $test->{'test_start_line'}" . ($test->{'loop_variable'} ? ", loop: $test->{'loop_variable'}" : '');
        push @parsed => sprintf 'my %s = qq{%s};' => $expected_var, join "\n" => @{ $test->{'lines_expected'} };

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

1;

=encoding utf-8

=head1 NAME

MojoX::CustomTemplateFileParser::Plugin::To::Test - Create tests

=head1 SYNOPSIS

  use MojoX::CustomTemplateFileParser;

  my $parser = MojoX::CustomTemplateFileParser->new(path => '/path/to/file.mojo', output => ['Test']);

  print $parser->to_test;

=head1 DESCRIPTION

MojoX::CustomTemplateFileParser::Plugin::To::Test is an output plugin to L<MojoX::CustomTemplateFileParser>.

=head2 to_test()

This method is added to L<MojoX::CustomTemplateFileParser> objects created with C<output =E<gt> ['Test']>.

It returns a string ready to be put in a L<Test::More> file.

=head1 SEE ALSO

=over 4

=item * L<Dist::Zilla::Plugin::Test::CreateFromMojoTemplates>

=item * L<MojoX::CustomTemplateFileParser::Plugin::To::Html>

=item * L<MojoX::CustomTemplateFileParser::Plugin::To::Pod>

=back

=head1 AUTHOR

Erik Carlsson E<lt>info@code301.comE<gt>

=head1 COPYRIGHT

Copyright 2014- Erik Carlsson

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
