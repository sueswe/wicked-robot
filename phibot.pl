#!/usr/bin/perl

##############################################################################
#
# phibot
#
# Ein irc roboter, der Befehle entgegen nimmt.
# 
# (c) 2013, <suess_w@gmx.net>
#
##############################################################################

##############################################################################
my $server = "aiki-base.dyndns.org";
my $nick = "phibot";
my $login = "phibot";
my $channel = "#phibot";
##############################################################################

use warnings;
use strict;
use IO::Socket;

$|=1;

our (%actions);
reload_actions();

# Verbinde zum IRC server.
print "Verbinde mich zum Server $server ... ";
my $sock = new IO::Socket::INET(
    PeerAddr => $server,
    PeerPort => 6667,
    Proto => 'tcp') or die "Verbindung nicht möglich: \n--> $! \n";
 
# Login:
print $sock "NICK $nick\r\n";
print $sock "USER $login 8 * :Perl IRC Hacks Robot\r\n";
 
while (my $input = <$sock>) {
    # Achte auf response vom Server
    if ($input =~ /004/) {
        # Jetzt sind wir angemeldet
        last;
    }
    elsif ($input =~ /433/) {
        die "Sorry, Nickname ist schon in Verwendung. \n";
    }
}
 
# Join:
print $sock "JOIN $channel\r\n";
print $sock "NOTICE $channel :Hello everyone!\r\n";
 
#sleep(3);
#print $sock "PART $channel :Good bye.\n";

while (my $input = <$sock>) {
    chop $input;
    print "$input\n";
    if ($input =~ /^PING(.*)$/i) {
        # respond to PINGs to avoid disconnects.
        print "I received a PING\n";
        print $sock "PONG $1\r\n";
    }
    if ($input =~ m/PRIVMSG $nick :reload/ig ) { 
        print $sock "NOTICE $channel :Reloading actions file \r\n";
        reload_actions(); 
    }
    
    if ($input =~ m/$channel :$nick:/ig ) { 
        execute("$input");
    }
    
}



##############################################################################
#
# FUNCTIONS
#
##############################################################################

sub reload_actions {
    print "Reloading actions.rc ... ";
    require("actions.rc") || warn("ERROR: $! \n");
    print "[OK]\n";
}

sub execute {
    my $command = shift;
    
    # wir benötigen hier eine suchfunktion!
    
    my $proc = $actions{$command};
    if ( ! defined $proc ) {
        print("nothing to do for $command");
        print $sock "NOTICE $channel :Da gibts nichts zu tun fuer mich =) \r\n";
    } else {
        print $sock "NOTICE $channel :Ich starte jetzt $proc \r\n";
        runcmd("$proc");
    }
    
}

sub runcmd {
    my (@command) = @_;
    open(FH,"-|","@command") || print $sock "NOTICE $channel :Probleme mit [@command]: $! \r\n";
    while(<FH>) {
        my $out .= $_;
        my $timestamp = localtime();
        print "($timestamp): $out";
    }
    close(FH);
}
