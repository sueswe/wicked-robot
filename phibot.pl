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
    Proto => 'tcp') or die "Verbindung nicht m�glich: \n--> $! \n";
 
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

# Keep us alive:
while (my $input = <$sock>) {
    chomp($input);
    print "[IN] $input\n";
    if ($input =~ /^PING(.*)$/i) {
        # respond to PINGs to avoid disconnects.
        # print "[INFO] I received a PING \n";
        print $sock "PONG $1\r\n";
    } elsif 
    # <reload>
    ($input =~ m/PRIVMSG $channel :$nick: reload/ig ) { 
        print $sock "PRIVMSG $channel :Okay, ich habe das config-file neu geladen. \r\n";
        reload_actions(); 
    } elsif 
    # <rules>
    ($input =~ m/PRIVMSG $channel :$nick: rules/ig ) {
        read_actions();
    } elsif
    # <part>
    ($input =~ m/PRIVMSG $channel :$nick: leave/ig || $input =~ m/PRIVMSG $channel :$nick: part/ig ) {
        part();
    } elsif
    # <hilfe>
    ($input =~ m/PRIVMSG $channel :$nick: hilfe/ig ) {
        hilfe();
    }
    # <actions.rc>
    elsif ($input =~ m/$channel :$nick:/ig ) { 
        execute("$input");
    }
}



##############################################################################
#
# FUNCTIONS
#
##############################################################################

sub execute {
    my ($command) = @_;
    $command =~ s/\r/\n/ig;
    $command =~ s/\e//ig;
    $command =~ s/\n//ig; 
    print "[COMMAND] $command \n";
    my @array = split(':',$command);
    my $anz = @array;
    my $p = $array[$anz - 1];
    $p =~ s/\s+//ig;
    print "[INFO] proc: \"$p\" \n";
    my $proc = $actions{$p};
    if ( ! defined $proc ) {
        print("[INFO]: nothing to do for $command \n");
        print $sock "PRIVMSG $channel :Ich habe keine passende Aktion gefunden zu Kommando: $p \r\n";
    } else {
        print $sock "PRIVMSG $channel :Werde $proc durchfuehren ... \r\n";
        runcmd("$proc");
    }
    
}


sub reload_actions {
    print "Reloading actions.rc ... ";
    require("actions.rc") || warn("ERROR: $! \n");
    print "[OK]\n";
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
    exit(100);
}


sub hilfe {
    print "Help called.\n";
    print $sock "PRIVMSG $channel :Hilfe: reload,rules,leave,part,hilfe \r\n";
}
