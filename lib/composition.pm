package composition;

use strict;

our $VERSION = '0.01';

sub import {
	my $class = shift;
	
	my $what = shift;
	my $prev;
	for my $pkg (@_) {
		no strict 'refs';
		
		unless (%{$pkg.'::'}) {
			unless (eval "require $pkg") {
				_make_pkg($pkg, $prev||$what);
				$prev = $pkg;
				next;
			}
		}
		
		if ($prev) {
			for my $parent (@{$pkg.'::ISA'}) {
				if ($parent eq $what) {
					$parent = $prev;
					last;
				}
			}
		}
		$prev = $pkg;
	}
}

sub _make_pkg {
	my ($name, $isa) = @_;
	
	no strict 'refs';
	@{$name.'::ISA'} = $isa;
}

1;

__END__

=pod

=head1 NAME

composition - make modules composition

=cut
