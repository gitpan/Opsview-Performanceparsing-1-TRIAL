package Opsview::Performanceparsing;

# ABSTRACT: Does the performance parsing duplicating logic in Nagiosgraph

use strict;
use warnings;
use Carp 'croak';
use Nagios::Plugin::Performance;


our $VERSION = '1';


sub init {
    my ( $class, $base_dir ) = @_;

    $base_dir ||= '/usr/local/nagios/etc';

    my $rules = do { local ( @ARGV, $/ ) = "$base_dir/map"; <> };

    # Also check for and load in a map.local override file.
    if ( -f '/usr/local/nagios/etc/map.local' ) {
        $rules .= do { local ( @ARGV, $/ ) = "$base_dir/map.local"; <> };
    }

    eval q/
        sub evalrules {
            $_ = $_[0];
            my @s;
            no strict 'subs';
        / . $rules . q/
            use strict 'subs';
            return @s;
        }
    /;
    croak "Map file eval error: $@" if $@;

    return 1;
}


sub new {
    my ( undef, $data ) = @_;
    return bless {
        label => $data->{label},
        value => $data->{value},
        uom   => $data->{uom},
    };
}


sub parseperfdata {
    my ( undef, %data ) = @_;

    my @rules = evalrules(
        "servicedescr:$data{servicename}\noutput:$data{output}\nperfdata:$data{perfdata}"
    );

    if ( scalar @rules ) {
        my @result;
        my $perfs = shift @rules;
        shift @$perfs; # Ignore first field

        foreach my $p (@$perfs) {
            push @result,
              __PACKAGE__->new(
                {
                    label => $p->[0],
                    value => $p->[2],
                    uom   => '',
                }
              );
        }
        return \@result;
    }

    my @data = Nagios::Plugin::Performance->parse_perfstring( $data{perfdata} );
    my @list;
    foreach my $p (@data) {
        my $label = $p->clean_label;
        push @list,
          __PACKAGE__->new(
            {
                label => $label,
                value => $p->value,
                uom   => $p->uom,
            }
          );
    }
    return \@list;

}


1;

__END__

=pod

=head1 NAME

Opsview::Performanceparsing - Does the performance parsing duplicating logic in Nagiosgraph

=head1 VERSION

version 1

=head1 SYNOPSIS

This is a wrapper around Nagios::Plugin::Performance, specifically for Opsview.
It handles the performance parsing duplicating logic of Nagiosgraph.

    Opsview::Performanceparsing->init;

    Opsview::Performanceparsing->parseperfdata(
        servicename => "Check Memory",
        output =>
          "Memory: total 1024 MB, active 121 MB, inactive 790 MB, wired: 91 MB, free: 22 MB (2%)",
        perfdata => "",
    );

=head1 NAME

Opsview::Performanceparsing

This package does the performance parsing duplicating logic in Nagiosgraph.

=head1 VERSION

Version 1

=head1 SUBROUTINES/METHODS

=head2 init

Class method that loads Nagios' map file. Default location is
'/usr/local/nagios/etc/map', but can be passed a directory where the map file
resides, if elsewhere. A map.local file, if exists, overrides the map file.

=head2 new

Create an object instance of this class. Pass it the desired label, value, and uom.

=head2 parseperfdata( servicename => $name, output => $output, perfdata => $perfdata )

Parses the data based on rules. Will return a listref of objects where you can
access the label, value and uom.

=head1 AUTHOR

Opsview Bynight, C<< <paul.knight at opsview.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-opsview-performanceparsing
at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Opsview-Performanceparsing>. I
will be notified, and then you'll automatically be notified of progress on your
bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Opsview::Performanceparsing

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Opsview-Performanceparsing>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Opsview-Performanceparsing>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Opsview-Performanceparsing>

=item * Search CPAN

L<http://search.cpan.org/dist/Opsview-Performanceparsing/>

=back

=head1 ACKNOWLEDGEMENTS

=head1 LICENSE AND COPYRIGHT

Copyright 2013 Opsview Bynight.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=head1 AUTHOR

Opsview Bynight <paul.knight@opsview.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Opsview Ltd.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
