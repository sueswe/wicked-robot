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
my $channel = "#scheduling";
##############################################################################

use warnings;
use strict;
use IO::Socket;

$|=1;

our %actions;
require("actions.rc") || warn("ERROR: $! \n");

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
print $sock "PRIVMSG $channel :Zu ihren Diensten. Verwende mich mit $nick: <command>\r\n";

# Keep us alive:
while (my $input = <$sock>) {
    chomp($input);
    print "[IN] $input\n";
    if ($input =~ /^PING(.*)$/i) {
        # respond to PINGs to avoid disconnects.
        # print "[INFO] I received a PING \n";
        print $sock "PONG $1\r\n";
        #print $sock "PRIVMSG $channel :PONG :-) \r\n";
    } elsif 
    # <reload>
    ($input =~ m/$nick/ig && $input =~ m/reload/ig ) { 
        reload_actions(); 
    } elsif 
    # <rules>
    ($input =~ m/$nick/ig && $input =~ m/rules/ig ) {
        read_actions();
    } elsif
    # <part>
    ($input =~ m/$nick/ig && $input =~ m/leave/ig ) {
        part();
    } elsif
    # <hilfe>
    ($input =~ m/$nick/ig && $input =~ m/help/ig || $input =~ m/hilf/ig ) {
        hilfe();
    } elsif
    ($input =~ m/$nick/ig && $input =~ m/bier/ig ) {
        beer("$input");
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
    
    my @usersuche = split('!',$command);
    my $you = $usersuche[0];
    $you =~ s/://ig;
    
    my $anz = @array;
    my $p = $array[$anz - 1];
    $p =~ s/^\s//ig;
    #$p =~ s/$\s//ig;
    
    print "[INFO] proc: \"$p\" \n";
    my $proc = $actions{$p};
    if ( ! defined $proc ) {
        print("[INFO]: nothing to do for $command \n");
        print $sock "PRIVMSG $channel :Ich habe keine passende Aktion gefunden zu Kommando: $p \r\n";
        print $sock "PRIVMSG $channel :$you: Sprich mich mal mit help an :-) \r\n";
    } else {
        print $sock "PRIVMSG $channel :$you: Werde $proc durchfuehren ... \r\n";
        runcmd("$proc");
    }
    
}


sub reload_actions {
    print $sock "PRIVMSG $channel :Ich lade das config-file neu. \r\n";
    print "Reloading actions.rc ... ";
    do("actions.rc") || warn("ERROR: $! \n");
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
    print $sock "PRIVMSG $channel :Folgene Eintraege sind in der actions.rc : \n\r";
    foreach my $g (keys %actions) {
        print "[INFO]: $g \t--> $actions{$g}\n";
        print $sock "PRIVMSG $channel :Kommando $g = $actions{$g} \n\r";
    }
}

sub part {
    print $sock "PART $channel :Good bye. \n";
    exit(100);
}


sub beer {
    my ($command) = @_;
    my @usersuche = split('!',$command);
    my $you = $usersuche[0];
    $you =~ s/://ig;
    print $sock "PRIVMSG $channel :$you, ich habe dir ein Bier bei http://www.duff-shop.at/ bestellt. \r\n";
}

sub hilfe {
    print "Help called.\n";
    print $sock "PRIVMSG $channel :reload = Lade actions.rc neu (bspw. nach Aenderungen) \r\n";
    print $sock "PRIVMSG $channel :rules  = Zeige mir die eingestellten Kommandos in der actions.rc \r\n";
    print $sock "PRIVMSG $channel :leave  = Ich verlasse den Server \r\n";
    print $sock "PRIVMSG $channel :bier   = ich bestelle dir ein Bier \r\n";
     
    
}


