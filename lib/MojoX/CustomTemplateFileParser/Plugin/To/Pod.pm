package MojoX::CustomTemplateFileParser::Plugin::To::Pod;

use strict;
use warnings;
use 5.10.1;
our $VERSION = '0.09';

use Moose::Role;

sub to_pod {
    my $self = shift;
    my $test_index = shift;
    my $want_all_examples = shift || 0;

    my $tests_at_index = $self->test_index->{ $test_index };
    my @out = ();

    TEST:
    foreach my $test (@{ $tests_at_index }) {
        next TEST if $want_all_examples && !$test->{'is_example'};

        if(scalar @{ $test->{'lines_before'} }) {
            push @out => '=begin html',
                      '<p>', @{ $test->{'lines_before'} }, '</p>',
                      '=end html',
                      "\n";
        }

        push @out => @{ $test->{'lines_template'} }, "\n";
        if(scalar @{ $test->{'lines_between'} }) {
            push @out => '=begin html',
                      '<p>',@{ $test->{'lines_between'} }, '</p>',
                      '=end html',
                      "\n";
        }
        push @out => @{ $test->{'lines_expected' } }, "\n";
        if(scalar @{ $test->{'lines_after'} }) {
            push @out => '=begin html',
                      '<p>',@{ $test->{'lines_after'} }, '</p>',
                      '=end html';
        }
    }

    my $out = join "\n" => @out;
    $out =~ s{\n\n\n+}{\n\n}g;

    return $out;

}

1;


=encoding utf-8

=head1 NAME

MojoX::CustomTemplateFileParser::Plugin::To::Pod - Create pod

=head1 SYNOPSIS

  use MojoX::CustomTemplateFileParser;

  my $parser = MojoX::CustomTemplateFileParser->new(path => '/path/to/file.mojo', output => ['Pod']);

  print $parser->to_pod;

=head1 DESCRIPTION

MojoX::CustomTemplateFileParser::Plugin::To::Pod is an output plugin to L<MojoX::CustomTemplateFileParser>.

=head2 to_pod()

This method is added to L<MojoX::CustomTemplateFileParser> objects created with C<output =E<gt> ['Pod']>.

=head1 SEE ALSO

=over 4

=item * L<Dist::Zilla::Plugin::InsertExample::FromMojoTemplates>

=item * L<MojoX::CustomTemplateFileParser::Plugin::To::Pod>

=item * L<MojoX::CustomTemplateFileParser::Plugin::To::Test>

=back

=head1 AUTHOR

Erik Carlsson E<lt>info@code301.comE<gt>

=head1 COPYRIGHT

Copyright 2014- Erik Carlsson

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
