package HtmlUtils;

use strict;
use parent 'Exporter';

our @EXPORT_OK = qw/untag/;

sub untag {
	my $str = shift;
	if ($str =~ /<[^<>]*$/) {
		$str .= ">";
	}
	$str =~ s/<[^>]*>/ /g;
	$str =~ s/\s+/ /g;
	$str;
}

1;
