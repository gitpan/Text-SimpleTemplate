# -*- mode: perl -*-
#
# $Id: SimpleTemplate.pm,v 1.7 1999/10/24 13:33:44 tai Exp $
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
It was first written for dynamic HTML generation, but should be
able to handle any kinds of dynamic text generation.

Major goal of this library is to separate code and data, so
non-programmer can control final result (like HTML output) as
desired without tweaking the source.

The idea is simple. Whenever the library finds text surrounded by
'<%' and '%>' (or any pair of strings you specify), it will evaluate
the part as a Perl expression, and will replace it by the evaluated
result.

For people who know Text::Template (which offers similar functionality)
already, you can consider this library almost same but with more strict
interface. Also, this library seems to run nearly twice as faster.

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

In addition to its native interface for exporting data to
template namespace, this module also supports Text::Template
compatible style of exporting.

Just do it as you had done with Text::Template:

    $FOO::text = 'hello, world';
    @FOO::list = qw(foo bar baz);

    $tmpl = new Text::SimpleTemplate;
    ...
    $tmpl->fill(PACKAGE => 'FOO');

=head1 METHODS

Following methods are currently available.

=over 4

=cut

use Carp;

use strict;
use vars qw($DEBUG $VERSION);

$DEBUG   = 0;
$VERSION = '0.32';

=item $tmpl = new Text::SimpleTemplate;

Constructor. This will create (and return) object reference to
Text::SimpleTemplate object.

If new object was cloned from existing Text::SimpleTemplate
object, every data except for template buffer will be inherited
by new child instance. This is useful for chained template processing.

=cut
sub new {
    my $name = shift;
    my $self = bless { hash => {} }, ref($name) || $name;

    ## inherit parent configuration
    if (ref($name)) {
        while (my($k, $v) = each %{$name}) {
            $self->{$k} = $v unless $k eq 'buff';
        }
    }
    $self;
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

As a option, this method accepts DELIM option, which specifies
delimiter to use on parsing. It takes a reference to array of
delimiter pair, just like below:

    $tmpl->load($file, DELIM => [qw(<? ?>)]);

There once was LR_CHAR option which provided almost same feature,
but it is now obsolete (though still supported). Main difference
is you now have no need to "quotemeta" delimiter, which was a cause
of trouble when meta character was in delimiter string.

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
    my %opts;

    ##
    ## I used to build internal document structure here, but it
    ## seems it's much faster to just make a copy and let Perl
    ## do the parsing on every evaluation stage...
    ##

    $self->{buff} = shift;

    %opts = @_;

    $self->{L_CH}   = $opts{LR_CHAR}->[0]          if $opts{LR_CHAR};
    $self->{L_CH}   = quotemeta($opts{DELIM}->[0]) if $opts{DELIM};
    $self->{L_CH} ||= '<%';

    $self->{R_CH}   = $opts{LR_CHAR}->[1]          if $opts{LR_CHAR};
    $self->{R_CH}   = quotemeta($opts{DELIM}->[1]) if $opts{DELIM};
    $self->{R_CH} ||= '%>';

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

works. If Safe module was passed, its reval method
will be used instead of built-in eval.

OHANDLE option is for output selection. By default, this
method returns the result of evaluation, but with OHANDLE
option set, you can instead make it print to given handle.
Either style of

    $tmpl->fill(OHANDLE => \*STDOUT);
    $tmpl->fill(OHANDLE => new FileHandle(...));

is supported.

=cut
sub fill {
    my $self = shift;
    my %opts = @_;
    my $from = $opts{PACKAGE} || caller;
    my $hand = $opts{OHANDLE};
    my $buff;
    my $name;
    my $eval;

    no strict;

    ## dynamically create evaluation engine
    if (UNIVERSAL::isa($from, 'Safe')) {
        $name = $from->root;
        $eval = sub { my $v = $from->reval($_[0]); $@ ? $@ : $v; }
    }
    else {
        $name = ref($from) || $from;
        $eval = eval qq{
            package $name; sub { my \$v = eval(\$_[0]); \$@ ? \$@ : \$v; };
        };
    }

    ## export stored data to target namespace
    while (my($key, $val) = each %{$self->{hash}}) {
        if ($DEBUG) {
            print STDERR "Exporting to ${name}::${key}: $val\n";
        }
        ${"${name}::${key}"} = $val;
    }

    my $L = $self->{L_CH};
    my $R = $self->{R_CH};

    ## parse and evaluate
    $buff = $self->{buff};
    $buff =~ s|$L(.*?)$R|$eval->($1)|seg;
#    $buff =~ s{^(.*?[^\\])?$L(.*?[^\\])$R}
#              {(defined($1) ? $1 : "") . $eval->($2)}sgex;
#    $buff =~ s/\\($L|$R)/$1/g;
    $hand ? print($hand $buff) : $buff;
}

=back

=head1 SEE ALSO

L<Safe> and L<Text::Template>

=head1 BUGS / COMMENTS

Please send any bug reports/comments/suggestions to
Taisuke Yamada <tai@imasy.or.jp>.

=head1 AUTHORS / CONTRIBUTORS

 - Taisuke Yamada <tai@imasy.or.jp>
 - Lin Tianshan <lts@www.qz.fj.cn>

=head1 COPYRIGHT

All rights reserved.

This library is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut

1;
