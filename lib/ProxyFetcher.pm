package ProxyFetcher;

use strict;
use DBI;
use DBD::mysql;

sub new {
	my ($class, %opts) = @_;
	
	my $self = {
		dbh => DBI->connect(
			"dbi:mysql:database=" . $opts{name} . ';host=' . $opts{host} . ';mysql_connect_timeout=10',
			$opts{user},
			$opts{pass},
			{RaiseError => 1, mysql_auto_reconnect => 1, mysql_enable_utf8 => 1, PrintError => 0}
		)
	};
	
	bless $self, $class;
}

sub fetch {
	my ($self) = @_;
	
	my $sth = $self->{dbh}->prepare('select host, port, login, password from proxy where status=1 AND timestampdiff(minute, check_date, now())<10 order by fails_cnt');
	$sth->execute();
	
	my @list;
	while (my ($host, $port, $login, $password) = $sth->fetchrow_array()) {
		push @list, sprintf('socks://%s:%s@%s:%d', $login, $password, $host, $port);
	}
	
	die "No proxy!" unless @list;
	
	return \@list;
}

1;
