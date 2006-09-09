package File::RandomLine;
use 5.006;
use strict;
use warnings;
use Carp;
our $VERSION = "0.17";

# Required modules
use Want 'howmany';

#--------------------------------------------------------------------------#
# main pod documentation #####
#--------------------------------------------------------------------------#

=head1 NAME

File::RandomLine - Retrieve random lines from a file

=head1 SYNOPSIS

  # Fast but biased randomness
  use File::RandomLine;
  my $rl = File::RandomLine->new('/var/log/messages');
  print $rl->next;
  print join("\n",$rl->next(3));
  
  # Slow but uniform randomness
  $rl = File::RandomLine->new('/var/log/messages', {algorithm=>"uniform"});
  
=head1 DESCRIPTION

This module provides a very fast random-access algorithm to retrieve random
lines from a file.  Lines are not retrieved with uniform probability, but
instead are weighted by the number of characters in the previous line, due to
the nature of the algorithm. Lines are most random when all lines are about
the same length.  For log file sampling or quote/fortune generation, this
should be "random enough".  Note -- when getting multiple lines, this module
resamples with replacement, so duplicate lines are possible.  Users will need
to check for duplication on their own if this is not desired.

The algorithm is as follows:

=over

=item *

Seek to a random location in the file

=item *

Read and discard the line fragment found

=item *

Read and return the next line, or the first line if we've reached the end
of the file

=item *

Repeat until the requested number of random lines have been found

=back

This module provides some similar behavior to L<File::Random>, but the
random access algorithm is much faster on large files.  (E.g., it runs
nearly instantaneously even on 100+ MB log files.)

This module also provides an optional, slower algorithm that returns random lines
with uniform probability.

=head1 USAGE

=cut

#--------------------------------------------------------------------------#
# new()
#--------------------------------------------------------------------------#

=head2 C<new>

 $rl = File::RandomLine->new( "filename" );
 $rl = File::RandomLine->new( "filename", { algorithm => "uniform" } );

Returns a new File::RandomLine object for the given filename.  The filename
must refer to a readable file.  A hash reference may be provided as an 
optional second argument to specify an algorithm to use.  Currently supported
algorithms are "fast" (the default) and "uniform".  Under "uniform", the 
module indexes the entire file before selecting random lines with true uniform
probability for each line.  This can be significantly slower on large files.

=cut

sub new {
	my ($class, $filename, $args) = @_;
    croak "new requires a filename parameter" unless $filename;
    my $algo = $args->{algorithm};
    croak "unknown algorithm '$algo'" if $algo && $algo !~ /fast|uniform/i;
    open(my $fh, $filename) or croak "Can't read $filename";
    my $line_index = lc $algo eq 'uniform' ? _index_file($fh) : undef ;
    my $filesize = -s $fh;
    my $self = { 
        fh => $fh, 
        line_index => $line_index, 
        line_count => $line_index ? scalar @$line_index : undef,
        filesize => $filesize 
    };
    return bless( $self, ref($class) ? ref($class) : $class );
}
	
#--------------------------------------------------------------------------#
# _index_file
#--------------------------------------------------------------------------#

sub _index_file {
    my ($fh) = @_;
    my @index;
    while (! eof $fh) {
        push @index, tell $fh;
        <$fh>;
    }
    return \@index;
}

#--------------------------------------------------------------------------#
# next()
#--------------------------------------------------------------------------#

=head2 C<next>

 $line = $rl->next();
 @lines = $rl->next(5);
 ($line1, $line2, $line3) = $rl->next();

Returns one or more lines from the file.  Without parameters, returns a
single line if called in scalar context.  With a positive integer parameter, 
returns a list with the specified number of lines.  C<next> also has some 
magic if called in list context with a finite length list of l-values and 
will return the proper number of lines.  


=cut

sub next {
	my ($self,$n) = @_;
    #  behavior copied from File::Random
    if (!defined($n) and wantarray) {
        $n = howmany();
        $n ||= 1;
    }
    unless (!defined($n) or $n =~ /^\d+$/) {
        croak "Number of random_lines should be a positive integer, not '$n'";
    }
    carp "Strange call to File::Random->next(): 0 random lines requested"
        if defined($n) and $n == 0;
    $n ||= 1;
    my @sample;
    while (@sample < $n) {
        push @sample, $self->{line_index} ? $self->_uniform : $self->_fast;
    }
    chomp @sample;
    return wantarray ? @sample : shift @sample;
}


#--------------------------------------------------------------------------#
# Fast Algorithm
#--------------------------------------------------------------------------#

sub _fast {
    my $self = shift;
    my $fh = $self->{fh};
    seek($fh,int(rand($self->{filesize})),0);
    <$fh>; # skip this fragment of a line
    seek($fh,0,0) if eof $fh; # wrap if hit EOF
    return scalar <$fh>; # get the next line
}

#--------------------------------------------------------------------------#
# Uniform Algorithm
#--------------------------------------------------------------------------#

sub _uniform {
    my $self = shift;
    my $fh = $self->{fh};
    my $start = $self->{line_index}[int(rand($self->{line_count}))];
    seek($fh,$start,0);
    return scalar <$fh>; # get the next line
}

1; #this line is important and will help the module return a true value
__END__

=head1 INSTALLATION

The following commands will build, test, and install this module:

 perl Build.PL
 perl Build
 perl Build test
 perl Build install

=head1 BUGS

Please report bugs using the CPAN Request Tracker at 
http://rt.cpan.org/NoAuth/Bugs.html?Dist=File-RandomLine

=head1 AUTHOR

David A Golden <dagolden@cpan.org>

http://dagolden.com/

=head1 COPYRIGHT

Concept and code for "magic" behavior in array context taken from 
L<File::Random> by Janek Schleicher.

All other code Copyright (c) 2005 by David A. Golden.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=head1 SEE ALSO

=over

=item *

L<File::Random>

=item *

"Re^2: selecting N random lines from a file in one pass", 
perlmonks.org, static URL: http://perlmonks.thepen.com/417065.html

=back

=cut
