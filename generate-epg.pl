#!/usr/bin/perl

package xmltvepg;

$| = 1;

use warnings FATAL => 'all';
use strict;

use DateTime;
use DateTime::Format::Strptime qw(strptime);
use JSON;
use JSON::Parse 'parse_json';
use HTTP::Request ();
use LWP::UserAgent;
use URI::Escape;
use UUID::Tiny ':std';
use File::Which;
use File::Spec;
use Data::Dumper;
use open qw( :std :encoding(UTF-8) );

my $listurl = "https://live.tvspielfilm.de/static/content/channel-list/livetv";
my $channeltemplate = "https://live.tvspielfilm.de/static/broadcast/list/#id/#date";
my $daytofetch = 7;
my $epgfile = "xmltv-tvs.xml";

sub get_json {
    my ($url) = @_;
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
    $date = $date->add(days => $days);
    my $datestring = $date->strftime('%Y-%m-%d');
    my $url = $channeltemplate;
    $url =~ s/#id/$channelid/ig;
    $url =~ s/#date/$datestring/ig;
    return $url;
}

sub process_timeline4channel {
    my ($channelid, $filehandler, $channelname) = @_;
    printf("\tProcessing $channelname... ");
    for(my $day = 0;$day < $daytofetch;$day++) {
        my @programOfDay = get_json(getProgramUrl($channelid, $day));
        for my $slot( @programOfDay ) {
             my $title = $slot->{title};
             my $timestart = DateTime->from_epoch($slot->{timestart});
             my $timeend = DateTime->from_epoch($slot->{timeend});
             my $description = " ";
             if(defined $slot->{text}) {
                 $description = $slot->{text};
             }

             print $filehandler "<programme start=\"".$timestart->strftime('%Y%m%d%H%M')."00000 +0000\" stop=\"".$timeend->strftime('%Y%m%d%H%M')."00000 +0000\" channel=\"".$channelid."\">\n";
             print $filehandler "<title lang=\"de\"><![CDATA[".$title."]]></title>\n";
             print $filehandler "<desc lang=\"de\"><![CDATA[".$description."]]></desc>\n";
             print $filehandler "</programme>\n";
        }
    }
    printf("ready.\n");
}

sub open_File {
    open(my $fh, '>', $epgfile) or die "Could not open file '$epgfile' $!";
    print $fh "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>\n";
    print $fh "<tv>\n";

    return $fh;
}

sub close_File {
    my ($fh) = @_;
    print $fh "\n</tv>\n\n\n";
    close $fh;
}

sub process {
    my ($fh) = @_;
    my @channellist = get_channellist;
    for my $channel( @channellist ) {
        my $channelid = $channel->{id};
        my $channelname = $channel->{name};
        my $logo = $channel->{image_small}->{url};
        print $fh "<channel id=\"".$channelid."\">\n";
        print $fh "<display-name lang=\"de\"><![CDATA[".$channelname."]]></display-name>\n";
        print $fh "<icon src=\"".$logo."\" />\n";
        print $fh "</channel>\n";
    }
    for my $channel( @channellist ) {
        process_timeline4channel($channel->{id}, $fh, $channel->{name});
    }
}

if(defined $ENV{EPGFILEPATH}) {
    my $sep = File::Spec->catfile('', '');
    $epgfile = $ENV{EPGFILEPATH}.$sep.$epgfile;
}

printf("create EPG-file...\n");
my $epgfilehandler = open_File;
printf("processing channels...\n");
process($epgfilehandler);
printf("finalize EPG-file...\n");
close_File($epgfilehandler);
printf("Finished.\n");