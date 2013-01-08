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
my $server  = "scheduling.sv.ooegkk.at";
my $nick    = "phibot";
my $login   = "phibot";
my $channel = "#test";
##############################################################################

use warnings;
use strict;
use IO::Socket;

$|=1;

our %actions;
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
        die "Nickname ist schon in Verwendung. \n";
    }
}
 
# Join:
print $sock "JOIN $channel\r\n";
print $sock "PRIVMSG $channel :Zu ihren Diensten. \r\n";

#read_actions();
#sleep(3);
#print $sock "PART $channel :Good bye. \n";
#exit(9);


while (my $input = <$sock>) {
    chop $input;
    print "$input\n";
    if ($input =~ /^PING(.*)$/i) {
        # respond to PINGs to avoid disconnects.
        # print "[INFO] I received a PING \n";
        print $sock "PONG $1\r\n";
    }
    # reload
    if ($input =~ m/PRIVMSG $channel :$nick: reload/ig ) { 
        print $sock "PRIVMSG $channel :Okay, ich habe das config-file neu geladen. \r\n";
        reload_actions(); 
    }
    # rules
    if ($input =~ m/PRIVMSG $channel :$nick: rules/ig ) {
        read_actions();
    }
    # part
    if ($input =~ m/PRIVMSG $channel :$nick: go away/ig ) {
        part();
    }
    # (actions.rc)
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
    my @array = split(':',$command);

    my $p = $array[$#array];
    print "[INFO] proc: $p \n";
    my $proc = $actions{$p};
    print "[INFO] Action: $proc \n";
    if ( ! defined $proc ) {
        print("[INFO]: nothing to do for $command \n");
        print $sock "PRIVMSG $channel :Da gibts nichts zu tun fuer mich =) \r\n";
    } else {
        print $sock "PRIVMSG $channel :Ich starte jetzt $proc \r\n";
        runcmd("$proc");
    }
    
}


sub runcmd {
    my (@command) = @_;
    open(FH,"-|","@command") || print $sock "PRIVMSG $channel :Probleme mit [@command]: $! \r\n";
    while(<FH>) {
        my $out .= $_;
        my $timestamp = localtime();
        print "($timestamp): $out";
    }
    close(FH);
}


sub read_actions {
    foreach my $g (keys %actions) {
        print "[INFO]: $g \t--> $actions{$g}\n";
        print $sock "PRIVMSG $channel :Kommando $g \t--> $actions{$g}\n";
    }
}

sub part {
    print $sock "PART $channel :Good bye. \n";
}



