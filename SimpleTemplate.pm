# -*- mode: perl -*-
#
# $Id: SimpleTemplate.pm,v 1.5 1999/10/21 15:51:09 tai Exp $
#

package Text::SimpleTemplate;

=head1 NAME

 Text::SimpleTemplate - Yet another library for template processing.

=head1 SYNOPSIS

 use Text::SimpleTemplate;

 $tmpl = new Text::SimpleTemplate;
 ...

=head1 DESCRIPTION

This is yet another library for template-based data generation.
It was first written to support dynamic generation of HTML pages,
but should be able to handle any kinds of dynamic text generation.
Major goal of this library is to separate code and data, so
non-programmer can control final result (like HTML output) as
desired without tweaking the source.

The idea is simple. Whenever the library finds text surrounded by
'<%' and '%>' (or any pair of strings you specify), it will evaluate
the part as a Perl expression, and will replace it by the evaluated
result.

For people who know Text::Template (which offers similar functionality)
already, you can consider this library almost same but with more strict
syntax for exporting and evaluating expression. This library seems to
run 20-30% faster, also.

=head1 TEMPLATE SYNTAX AND USAGE

Suppose you have a following template named "sample.tmpl":

    Hello, <% $to %>!
    Welcome, you are user with ID #<% $id->{$to} %>.

With the follwing code...

    use Safe;
    use Text::SimpleTemplate;

    $tmpl = new Text::SimpleTemplate;
    $tmpl->setq(to => 'tai', id => { tai => 10 });
    $tmpl->load("sample.tmpl");
    $tmpl->fill(OHANDLE => \*STDOUT, PACKAGE => new Safe);

...you will get following result:

    Hello, tai!
    Welcome, you are user with ID #10.

As you might have noticed, _any_ scalar variable can be exported,
even hash reference or code reference.

By the way, although the above example used Safe module, this
is not a requirement. I just wanted to show that you can use
it if you want to.

=head1 COMPATIBILITY

I first designed this module to require exporting of data to be
done explicitly. But I changed my mind and have also added
support for Text::Template compatible style of exporting.

Just do it as you had done with Text::Template:

    $FOO::text = 'hello, world';
    @FOO::list = qw(foo bar baz);

    $tmpl = new Text::SimpleTemplate;
    ...
    $tmpl->fill(PACKAGE => 'FOO');

I personally don't use this style, you might find it useful.

=head1 METHODS

Following methods are currently available.

=over 4

=cut

use strict;
#use diagnostics;

use Carp;

use vars qw($DEBUG $VERSION);

$DEBUG   = 0;
$VERSION = '0.06';

=item $tmpl = new Text::SimpleTemplate;

Constructor. This will create (and return) object reference to
Text::SimpleTemplate object.

=cut
sub new {
    bless { list => [], hash => {} }, shift;
}

=item $tmpl->setq($name => $data, $name => $data, ...);

Exports scalar data $data with name $name to template namespace (which
is dynamically set on later evaluation stage). You can repeat the pair
to export multiple variable pairs in one operation.

=cut
sub setq {
    my $self = shift;
    my %pair = @_;

    while (my($key, $val) = each %pair) {
        $self->{hash}->{$key} = $val;
    }
}

=item $tmpl->load($file, %opts);

Loads template file $file for later evaluation. $file can
either be a filename or a reference to filehandle.

As a option, this method accepts LR_CHAR option, which can be
used to specify delimiter to use on parsing. It takes a reference
to array of delimiter pair, just like below:

    $tmpl->load($file, LR_CHAR => [qw({ })]);

Returns object reference to itself.

=cut
sub load {
    my $self = shift;
    my $file = shift;
    my %opts = @_;
    my $buff;

    if (ref($file)) {
        $buff = join("", <$file>);
    }
    else {
        local(*FILE);

        open(FILE, $file) || croak($!);
        $buff = join("", <FILE>);
        close(FILE);
    }
    $self->pack($buff, %opts);
}

=item $tmpl->pack($data, %opts);

Instead of file, loads in-memory data $data as a template.
Except for this difference, works just like $tmpl->load.

=cut
sub pack {
    my $self = shift;
    my $data = shift;
    my %opts = @_;

    my $L = $self->{L} = $opts{LR_CHAR}->[0] || '<%';
    my $R = $self->{R} = $opts{LR_CHAR}->[1] || '%>';

    $self->init;
    $data =~ s|(.*?)$L(.*?)$R|$self->push($1, $2)|seg;
#    $data =~ s|^((.*?)[^\\])?$L((.*?)[^\\])?$R|$self->push($1, $3)|seg;
    $self->push($data);
    $self;
}

=item $text = $tmpl->fill(%opts);

Returns evaluated result of template. Note template must
be preloaded by either $tmpl->pack or $tmpl->load
method beforehand.

This method accepts two options: PACKAGE and OHANDLE.

PACKAGE option will let you specify the namespace
where template evaluation takes place. You can pass
either the name of the namespace, or the package object
itself. So either of

    $tmpl->fill(PACKAGE => new Safe);
    $tmpl->fill(PACKAGE => new Some::Module);
    $tmpl->fill(PACKAGE => 'Some::Package');

works. Note: Safe module is handled differently, so
reval method will be used instead of plain eval.

OHANDLE option is for output selection. By default, this
method returns the result of evaluation, but with OHANDLE
option set, you can instead make it print to given handle.
Either of

    $tmpl->fill(OHANDLE => \*STDOUT);
    $tmpl->fill(OHANDLE => new FileHandle(...));

is supported.

=cut
sub fill {
    my $self = shift;
    my %opts = @_;
    my $from = $opts{PACKAGE} || caller;
    my $hand = $opts{OHANDLE};
    my $name;
    my $eval;
    my $text;

    no strict;

    ## dynamically create evaluation engine
    if (UNIVERSAL::isa($from, 'Safe')) {
        $name = $from->root;
        $eval = sub {
            my $r = $from->reval($_[0]); $@ ? $@ : $r;
        };
    }
    else {
        $name = ref($from) || $from;
        $eval = eval qq{
            package $name;
            sub {
                my \$r = eval \$_[0]; \$@ ? \$@ : \$r;
            };
        };
    }

    ## export stored data to target namespace
    while (my($key, $val) = each %{$self->{hash}}) {
        if ($DEBUG) {
            print STDERR "Exporting to ${name}::${key}: $val\n";
        }
        ${"${name}::${key}"} = $val;
    }

    ## process each template element
    foreach (@{$self->{list}}) {
        print STDERR "Processing: $_\n" if $DEBUG;
        unless ($hand) {
            $text .= $_->{eval} ? $eval->($_->{data}) : $_->{data}; next;
        }
        print $hand $_->{eval} ? $eval->($_->{data}) : $_->{data};
    }
    $text;
}

sub init {
    shift->{list} = [];
}

sub push {
    my $self = shift;
    my $text = shift;
    my $expr = shift;

#    for ($text, $expr) {
#        s!\\($self->{R}|$self->{L})!$1!go if $_;
#    }

    push(@{$self->{list}}, { eval => 0, data => $text }) if $text;
    push(@{$self->{list}}, { eval => 1, data => $expr }) if $expr;
    '';
}

=back

=head1 SEE ALSO

L<Safe>, L<Template> and L<Text::Template>

=head1 COPYRIGHT

Copyright 1998-1999 T. Yamada <tai@imasy.or.jp>.
All rights reserved.

This library is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut

1;
