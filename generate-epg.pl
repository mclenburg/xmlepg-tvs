#!/usr/bin/perl

package xmltvepg;

$| = 1;

use warnings FATAL => 'all';
use strict;

use DateTime;
use DateTime::Format::Strptime qw(strptime);
use JSON;
use JSON::Parse ':all';
use HTTP::Request ();
use LWP::UserAgent;
use URI::Escape;
use UUID::Tiny ':std';
use File::Which;
use Data::Dumper;

my $listurl = "https://live.tvspielfilm.de/static/content/channel-list/livetv";
my $channeltemplate = "https://live.tvspielfilm.de/static/broadcast/list/#id/#date";
my $daytofetch = 7;

sub get_json {
    my $url = @_;
    my $request = HTTP::Request->new(GET => $url);
    my $useragent = LWP::UserAgent->new(keep_alive => 1);
    $useragent->agent('Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:86.0) Gecko/20100101 Firefox/86.0');
    my $response = $useragent->request($request);
    if ($response->is_success) {
        return @{parse_json($response->decoded_content)};
    }
    else{
        return ();
    }
}

sub get_channellist {
    return get_json($listurl);
}

sub getProgramUrl {
    my ($channelid, $days) = @_;
    my $date = DateTime->now();
    $date = $date->add(days => $day);
    $datestring = $date->strftime('%Y-%m-%d');
    my $url = $channeltemplate;
    $url =~ s/#id/$channelid/ig;
    $url =~ s/#date/$datestring/ig;
    return $url;
}

sub process_channel {
    my $channelid = @_;
    for(my $day = 0;$day < $daytofetch;$day++) {
        my $programOfDay = get_json(getProgramUrl($channelid, $day));

    }
}