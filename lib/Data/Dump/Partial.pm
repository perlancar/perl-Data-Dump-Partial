package Data::Dump::Partial;
# ABSTRACT: Dump data structure compactly and potentially partially

use 5.010;
use strict;
use warnings;
use Data::Dump::Filtered;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(dump_partial dumpp);

=head1 SYNOPSIS

 use Data::Dump::Partial qw(dump_partial dumpp);

 dump_partial([1, "some long string", 3, 4, 5, 6, 7]);
 # prints something like: [1, "some long st...", 3, 4, 5, ...]

 # specify options
 dump_partial($data, $more_data, {max_total_len => 50, max_keys => 4});

=head1 DESCRIPTION

=cut

=head1 FUNCTIONS

=head2 dump_partial(..., $opts)

Dump one more data structures compactly and potentially
partially. Uses L<Data::Dump::Filtered> as the backend. By compactly,
it means all indents and comments and newlines are removed, so the
output all fits in one line. By partially, it means only a certain
number of scalar length, array elements, hash keys are showed.

$opts is a hashref, optional only when there is one data to dump, with
the following known keys:

=over 4

=item * max_total_len => NUM

Total length of output before it gets truncated with an
ellipsis. Default is 80.

=item * max_len => NUM

Maximum length of a scalar (string, etc) to show before the rest get
truncated with an ellipsis. Default is 32.

=item * max_keys => NUM

Number of key pairs of a hash to show before the rest get truncated
with an ellipsis. Default is 5.

=item * max_elems => NUM

Number of elements of an array to show before the rest get truncated
with an ellipsis. Default is 5.

=item * precious_keys => [KEY, ...]

Never truncate these keys (even if it results in max_keys limit being
exceeded).

=item * worthless_keys => [KEY, ...]

When needing to truncate hash keys, search for these first.

=item * hide_keys => [KEY, ...]

Always truncate these hash keys, no matter what. This is actually also
implemented by Data::Dump::Filtered.

=item * dd_filter => \&sub

If you have other Data::Dump::Filtered filter you want to execute, you
can pass it here.

=back

=cut

sub dump_partial {
    my @data = @_;
    my $opts = (@data > 1) ? {%{pop(@data)}} : {};

    $opts->{max_keys}      //=  5;
    $opts->{max_elems}     //=  5;
    $opts->{max_len}       //= 32;
    $opts->{max_total_len} //= 80;

    $opts->{max_keys} = @{$opts->{precious_keys}} if $opts->{precious_keys} &&
        @{ $opts->{precious_keys} } > $opts->{max_keys};

    my $out;

    if ($opts->{_inner}) {
        #print "DEBUG: inner dump\n";
        $out = Data::Dump::dump(@data);
    } else {
        #print "DEBUG: outer dump\n";
        my $filter = sub {
            my ($ctx, $oref) = @_;

            if ($opts->{max_len} && $ctx->is_scalar && defined($$oref) &&
                    length($$oref) > $opts->{max_len}) {

                return { object => substr($$oref, 0, $opts->{max_len}-3)."..." };

            } elsif ($opts->{max_elems} && $ctx->is_array &&
                         @$oref > $opts->{max_elems}) {

                #print "DEBUG: truncating array\n";
                my @ary = @{$oref}[0..($opts->{max_elems}-1)];
                local $opts->{_inner} = 1;
                local $opts->{max_total_len} = 0;
                my $out = dump_partial(\@ary, $opts);
                $out =~ s/(?:, )?]$/, ...]/;
                return { dump => $out };

            } elsif ($opts->{max_keys} && $ctx->is_hash &&
                         keys(%$oref) > $opts->{max_keys}) {

                #print "DEBUG: truncating hash\n";
                my %hash = %$oref;
                my $mk = $opts->{max_keys};
                {
                    if ($opts->{hide_keys}) {
                        for (keys %hash) {
                            delete $hash{$_} if $_ ~~ @{$opts->{hide_keys}};
                        }
                    }
                    last if keys(%hash) <= $mk;
                    if ($opts->{worthless_keys}) {
                        for (keys %hash) {
                            last if keys(%hash) <= $mk;
                            delete $hash{$_} if $_ ~~ @{$opts->{worthless_keys}};
                        }
                    }
                    last if keys(%hash) <= $mk;
                    for (keys %hash) {
                        delete $hash{$_} if !$opts->{precious_keys} ||
                            !($_ ~~ @{$opts->{precious_keys}});
                        last if keys(%hash) <= $mk;
                    }
                }
                local $opts->{_inner} = 1;
                local $opts->{max_total_len} = 0;
                my $out = dump_partial(\%hash, $opts);
                $out =~ s/(?:, )? }$/, ... }/;
                return { dump => $out };

            } elsif ($opts->{dd_filter}) {

                return $opts->{dd_filter}->($ctx, $oref);

            } else {

                return;

            }
        };
        $out = Data::Dump::Filtered::dump_filtered(@data, $filter);
    }

    for ($out) {
        s/^\s*#.*//mg; # comments
        s/^\s+//mg; # indents
        s/\n+/ /g; # newlines
    }

    if ($opts->{max_total_len} && length($out) > $opts->{max_total_len}) {
        $out = substr($out, 0, $opts->{max_total_len}-3) . "...";
    }

    print STDERR "$out\n" unless defined wantarray;
    $out;
}

1;

=head2 dumpp

An alias for dump_filtered().

=cut

sub dumpp { dump_partial(@_) }

=head1 FAQ

=head2 What is the point/purpose of this module?

Sometimes you want to dump a data structure, but need it to be short,
more than need it to be complete, for example when logging to log
files or database.

=head2 Is the dump result eval()-able? Will the dump result eval() to produce the original data?

Sometimes it is/will, sometimes it does/will not if it gets truncated.

=head1 SEE ALSO

L<Data::Dump::Filtered>

=cut
