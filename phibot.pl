#!/usr/bin/perl

##############################################################################
#
# phibot
#
# A simple configureable command-irc-bot 
# 
# (c) 2013, <suess_w@gmx.net>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
##############################################################################

##############################################################################
my $server  = "localhost";
my $port = 6667;
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

print "Connectiong to $server ... ";
my $sock = new IO::Socket::INET(
    PeerAddr => $server,
    PeerPort => $port,
    Proto => 'tcp') or die "Problem: \n--> $! \n";
 
# Login:
print $sock "NICK $nick\r\n";
print $sock "USER $login 8 * :Perl IRC Hacks Robot\r\n";
 
while (my $input = <$sock>) {
    if ($input =~ /004/) {
        # login completed.
        last;
    }
    elsif ($input =~ /433/) {
        die "Nickname \"$nick\" already in use! \n";
    }
}
 
print $sock "JOIN $channel \r\n";
print $sock "PRIVMSG $channel :At your service. You can ask me for help. \r\n";

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
    ($input =~ m/$nick/ig && $input =~ m/action/ig ) {
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
        print $sock "PRIVMSG $channel :I'm sorry, I cannot find an operation for: $p \r\n";
    } else {
        print $sock "PRIVMSG $channel :$you: Ok, processing $proc ... \r\n";
        runcmd("$proc");
    }
    
}


sub reload_actions {
    print $sock "PRIVMSG $channel :Ok, reloading the configfile. \r\n";
    print "Reloading actions.rc ... ";
    do("actions.rc") || print($sock "PRIVMSG $channel :I had a problem reloading the configfile. Call the admin ... \r\n") && warn("ERROR: $! \n");
    print "[OK]\n";
}


sub runcmd {
    my (@command) = @_;
    open(FH,"-|","@command") || print $sock "PRIVMSG $channel :Uhoh: [@command]: $! \r\n";
    while(<FH>) {
        my $out .= $_;
        my $timestamp = localtime();
        print "($timestamp): $out";
    }
    close(FH);
}


sub read_actions {
    print $sock "PRIVMSG $channel :Found following actions : \n\r";
    foreach my $g (keys %actions) {
        print "[INFO]: $g \t--> $actions{$g}\n";
        print $sock "PRIVMSG $channel :Command $g = $actions{$g} \n\r";
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
    print $sock "PRIVMSG $channel :$you, you can order beer at http://www.duff-shop.at/  \r\n";
}

sub hilfe {
    print "Help called.\n";
    print $sock "PRIVMSG $channel :Well, maybe I can help you ... \r\n";
    print $sock "PRIVMSG $channel :reload = reloading actions.rc (e.g. after updating actions.rc file) \r\n";
    print $sock "PRIVMSG $channel :action  = show me the actions in the configfile \r\n";
    print $sock "PRIVMSG $channel :leave  = I will leave the server and exit \r\n";
    
}


