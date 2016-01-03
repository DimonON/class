use strict;
use utf8::all;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/lib";
use UserAgent;
use WWW::Mechanize::PhantomJS;
use Mojo::DOM;
use Getopt::Long;
use Text::CSV;
use Parse::JCONF;
use URI;
use Encode;
use Encode::Detect::Detector;
use Data::Printer;
use 5.010;
my $time = time;

GetOptions (
            "ua=s"      => \my $ua_arg,
            "site=s"    => \my $url,
            "file=s"    => \my $file_arg,
            "output=s"  => \my $output_file_arg,
            "config=s"  => \my $config_arg
            )
or die "Error in command line arguments\n";

# Validate parameters
if ( !$ua_arg or !$config_arg ) { die "USAGE: $0 -ua USERAGENT (LWP or PhantomJS) -site URL_HERE or -file URLs.csv [-output RESULTS.csv (only if -file argumrnt specified)] -config YOUR.conf\n" }
if ( $url && $file_arg or !$url && !$file_arg ) { die "ERROR! You must specify one of -site or -file arguments\n" }
if ( !$file_arg and $ua_arg !~ m!^(?:LWP|PhantomJS)$!i ) { die "ERROR! Unsupported UserAgent. Available values:\n\tLWP\n\tPhantomJS\n" }
if ( !$file_arg && $output_file_arg or $file_arg && !$output_file_arg) { die "ERROR! Use -file and -output arguments only together\n" }
if ( $url and $url !~ m!^https*:\/\/!i ) { die "ERROR! Incorrect site URI\n" }


my (%tags, @tags_row, %add_links, $base_uri);
my $config = Parse::JCONF->new(autodie => 1)->parse_file($config_arg)
    or die "ERROR! Can't open configuration file: $!";
#p $config;





sub get_tags($$) {
    my ($ua_arg, $url) = @_;
    my $body;
    if ($ua_arg =~ m!^LWP$!i) {
        my $ua = UserAgent->new(
                                requests_redirectable => [],
                                cache_dir => 'D:\_common\class\cache',
                                timeout => 10,
                                agent => 'Mozilla/5.0 (Windows NT 6.1; WOW64; rv:31.0) Gecko/20100101 Firefox/31.0',
                                recache_if => sub { shift->code >= 500 }
                                );
        
########my $ua = LWP::UserAgent->new( requests_redirectable => [] );
        my $res = $ua->get($url);
        
        my $i = 0;
        while (1) {
            if ($i > 7) { say "ERROR! Too many redirects"; return 0; }
            
            my $redirected = $res->header( 'location' );
            if ($redirected) {
                say "Redirected to: $redirected";
                $res = $ua->get($redirected);
                $i++;
                next;
            }
            last;
        }
        
        $body = $res->decoded_content;
        $base_uri = $res->base;
    }
    
    elsif ($ua_arg =~ m!^PhantomJS$!i) {
        my $mech = WWW::Mechanize::PhantomJS->new( log => 'OFF', phantomjs_arg => ['--config=D:/_common/class/config.json'] );
        $mech->get($url);
        $body = $mech->content;
        $base_uri = $mech->base;
    }
    
    
    my $dom = Mojo::DOM->new($body);
    #charset_detect($dom, $body);
    
    my %uris;
    map { $uris{$_} = 1 if (defined $_) } @{ $dom->find('a')->map( attr => 'href' ) };
    my %labels = map {$_ => 1} @{ $dom->find('a')->map(sub {$_->text} ) };
    #p %uris;
    #p %lables;
    
    foreach my $cur_key (keys %uris) {
        while ( my ($tag, $properties) = each %{$config->{regexp_for_uris}} ) {
            my $re = regexpo( $properties->{regexp} );
            if ($cur_key =~ m!$re!i) {
                $tags{$tag} = $cur_key;
                $tags_row[$properties->{index}] = $cur_key;
                if ($tag eq 'about_uri' or $tag eq 'contacts_uri') { $add_links{$cur_key} = 'from_uri'; }
            }
        }
    }
    
    foreach my $cur_key (keys %labels) {
        while ( my ($tag, $properties) = each %{$config->{regexp_for_lables}} ) {
            my $re = regexpo( $properties->{regexp} );
            if ($cur_key =~ m!$re!i) {
                $tags{$tag} = $cur_key;
                $tags_row[$properties->{index}] = $cur_key;
                if ($tag eq 'about' or $tag eq 'contacts') {
                    $dom->find('a')->each(sub {
                        $add_links{ $_->attr('href') } = 'from_lable' if ($_->text eq $cur_key);
                    });
                }
            }
        }
    }
    
    while ( my ($tag, $properties) = each %{$config->{regexp_for_body}} ) {
        my $re = regexpo( $properties->{regexp} );
        if ($body =~ m!$re!i) {
            $tags{$tag} = 1;
            $tags_row[$properties->{index}] = 1;
        }
    }
}


# Function construct regular expression from elements of list or return the single expression
sub regexpo($) {
    my $regexp = shift;
    return $regexp unless (ref $regexp);
    return my $expression = '(?:' . join('|', @$regexp) . ')';
}



sub get_headers() {
    my @headers;
    $headers[0] = 'URI';
    while ( my ($group, $tags) = each %$config ) {
        while ( my ($tag, $properties) = each %$tags ) {
            $headers[ $properties->{index} ] = $tag;
        }
    }
    push (@headers, 'tags_count');
    return \@headers;
}



sub go($$$) {
    my ($ua_arg, $url, $file_arg) = @_;
    say $url;
    $tags_row[0] = $url;
    get_tags($ua_arg, $url);
    
    if (keys %add_links) {
        foreach (keys %add_links) {
            my $url = URI->new_abs($_, $base_uri);
            get_tags($ua_arg, $url);
        }
    }
    
    if ($file_arg) { return \@tags_row; }
    else { return \%tags; }
}



sub charset_detect($$) {
    my ($dom, $body) = @_;
    
    my $dom_charset = detect($dom);
    my $body_charset = detect($body);
    say "Charsets\n    DOM: $dom_charset";
    say "    body: $body_charset";
}





if ($url) {
    my $tags = go($ua_arg, $url, $file_arg);
    p $tags;
}

elsif ($file_arg) {
    open(my $in_fh, "<", $file_arg)
        or die "ERROR! Can't open input file: $!";
    
    open(my $out_fh, ">", $output_file_arg)
        or die "ERROR! Can't open output file: $!";
    
    my $csv = Text::CSV->new( {binary => 1, eol => "\n", sep_char => ","} );
    
    my $output_file_headers = get_headers();
    $csv->print ($out_fh, $output_file_headers);
    
    
    while ( my $input_row = $csv->getline($in_fh) ) {
        my $url = $$input_row[0];
        my $row = go($ua_arg, $url, $file_arg);
        
        $$row[scalar(@$output_file_headers) - 1] = scalar(keys %tags);
        $csv->print ($out_fh, $row);
        
        undef %tags;
        undef @tags_row;
        undef %add_links;
    }
    
    close $out_fh;
}
say time - $time;