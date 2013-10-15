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
my $version = "0.3 rc2";
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
autoflush $sock 1;
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
print $sock "PRIVMSG $channel : At your service. You can ask me for help. (I am phi(φ)bot version $version ) \r\n";

# Keep us alive:
while (my $input = <$sock>) {
    chomp($input);
    print "[IN] $input\n";
    if ($input =~ /^PING(.*)$/i) {
        # respond to PINGs to avoid disconnects.
        print $sock "PONG $1\r\n";
        #print $sock "PRIVMSG $channel :PONG :-) \r\n";
    }
    elsif ( $input =~ m/JOIN/ig ) {
        joined("$input");
    }
    # <reload>
    elsif ($input =~ m/$nick/ig && $input =~ m/reload/ig ) { 
        reload_actions(); 
    } 
    # <rules>
    elsif ($input =~ m/$nick/ig && $input =~ m/action/ig ) {
        read_actions();
    } 
    # <part>
    elsif ($input =~ m/$nick/ig && $input =~ m/leave/ig ) {
        part();
    } 
    # <hilfe>
    elsif ($input =~ m/$nick/ig && $input =~ m/help/ig || $input =~ m/hilf/ig ) {
        hilfe();
    } 
    # beer
    elsif
    ($input =~ m/$nick/ig && $input =~ m/bier/ig ) {
        beer("$input");
    } 
    # show us the rules
    elsif ( $input =~ m/$nick/ig && $input =~ m/rules/ig || $input =~ m/regeln/ig ) {
        show_rules();
    }
    # do something from <actions.rc>
    elsif ($input =~ m/$channel :$nick:/ig ) { 
        execute("$input");
    }
    # tweet
    elsif ($input =~ m/ALERT/ig ) {
        my @a = split('@',$input);
        $a[2] =~ s/]/:/ig;
        #twitter("$a[2]");
    }
    # bueno fun
    elsif ( $input =~ m/$nick/ig && $input =~ m/bueno/ig ) {
        print $sock "PRIVMSG $channel : I have no more buenos. They were all eaten by Roland. :( \r\n";
    }
    # question?
    elsif ( $input =~ m/$nick/ig && $input =~ m/\?/ig ) {
        #print $sock "PRIVMSG $channel : I have no idea :( \r\n";
        print "Someone asked me a question. Calling Elli for help.\n";
        elli();
    }
    else {
        # ignored
    }
}



##############################################################################
#
# FUNCTIONS
#
##############################################################################

sub twitter {
    my (@string) = @_;
    system("/usr/bin/perl /home/sueswe/tweet.pl \"@string\"");
    print "twitit: perl /home/sueswe/tweet.pl \"@string\"\n";
}

sub joined {
    my ($command) = @_;
    $command =~ s/\r/\n/ig;
    $command =~ s/\e//ig;
    $command =~ s/\n//ig; 
    my @usersuche = split('!',$command);
    my $you = $usersuche[0];
    $you =~ s/://ig;
    print "$you joined\n";
    if ( $you =~ m/bot/ig ) {
        print "we do not greet a bot\n";
    } elsif ( $you ne $nick ) {
        print $sock "PRIVMSG $channel :Hello $you, welcome to $channel :) \r\n";
    }
}

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
    
    print "[DEBUG] Value from key: \"$p\" \n";
    
    my @T = split(' ',$p);
    print "[DEBUG] Input: @T \n";
    my $key = $T[0];
    shift(@T);
    print "[DEBUG] Input[0]: $key \n";
    my $programm = $actions{$key};
    
    if ( ! exists($actions{"$key"})  ) {
        print("[INFO]: nothing to do for $command \n");
        print $sock "PRIVMSG $channel :I'm sorry, I cannot find an operation for: $p You should write a script for it! :-) \r\n";
    } else {
        print $sock "PRIVMSG $channel :$you: Ok, processing @T ... \r\n";
        runcmd("$programm @T");
    }
    
}

sub reload_actions {
    print "Reloading actions.rc ... ";
    do("actions.rc") || print($sock "PRIVMSG $channel :I had a problem reloading the configfile. Call the admin ... [$!]\r\n") && warn("ERROR: $! \n");
    print "[OK]\n";
    print $sock "PRIVMSG $channel : actions.rc reloaded. \r\n";
}

sub runcmd {
    my (@command) = @_;
    open(FH,"-|","@command") || print $sock "PRIVMSG $channel :Uhoh: [@command]: $! \r\n";
    while(<FH>) {
        my $out .= $_;
        my $timestamp = localtime();
        print "($timestamp): $out";
        print $sock "PRIVMSG $channel : $out \n";
    }
    close(FH);
    my $RTC = $? >> 8;
    print $sock "PRIVMSG $channel :Returncode @command : $RTC .\r\n";
}

sub read_actions {
    print $sock "PRIVMSG $channel :Found following actions : \n\r";
    foreach my $g (sort keys %actions) {
        print "[INFO]: $g \t--> $actions{$g}\n";
        #print $sock "PRIVMSG $channel :Command $g = $actions{$g} \n\r";
        print $sock "PRIVMSG $channel :      $g \n\r";
    }
    print $sock "PRIVMSG $channel : Usage: phibot: <action> \n\r";
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
    print $sock "PRIVMSG $channel :  say \r\n";
    print $sock "PRIVMSG $channel :  $nick reload = reloading actions.rc (e.g. after updating actions.rc file) \r\n";
    print $sock "PRIVMSG $channel :  $nick actions  = show me the actions in the configfile \r\n";
    print $sock "PRIVMSG $channel :  $nick leave  = I will leave the server and exit \r\n";
    print $sock "PRIVMSG $channel :  $nick rules  = I will show you my rules \r\n";
    print $sock "PRIVMSG $channel :  $nick : <action>  = Start the action (beware of the ':') \r\n";
    
}

sub show_rules {
    #print $sock "PRIVMSG $channel : Ein Roboter darf keinen Menschen verletzen.\r\n";
    #print $sock "PRIVMSG $channel : Ein Roboter ist verpflichtet, mit Menschen zusammenzuarbeiten, es sei denn, diese Zusammenarbeit stünde im Widerspruch zum Ersten Gesetz.\r\n";
    #print $sock "PRIVMSG $channel : Ein Roboter muss seine eigene Existenz schützen, so lange er dadurch nicht in einen Konflikt mit dem Ersten Gesetz gerät.\r\n";
    #print $sock "PRIVMSG $channel : Ein Roboter hat die Freiheit zu tun, was er will, es sei denn, er würde dadurch gegen das Erste, Zweite oder Dritte Gesetz verstoßen.\r\n";
    #print $sock "PRIVMSG $channel : (http://de.wikipedia.org/wiki/Robotergesetze) \r\n";
    
    print $sock "PRIVMSG $channel : A robot may not injure a human being or, through inaction, allow a human being to come to harm. \r\n";
    print $sock "PRIVMSG $channel : A robot must obey the orders given to it by human beings, except where such orders would conflict with the First Law. \r\n";
    print $sock "PRIVMSG $channel : A robot must protect its own existence as long as such protection does not conflict with the First or Second Law. \r\n";
    print $sock "PRIVMSG $channel : (http://de.wikipedia.org/wiki/Robotergesetze \tThis is _NOT_ from AI movie.) \r\n";
}

sub elli {
    my $data = 'elli.txt';
    my $line;
    if ( ! -e $data ) {
        print $sock "PRIVMSG $channel : I have no idea :( \r\n";
    } else {
        open(TXT,"< $data");
        srand; 
        rand($.) < 1 && ( $line = $_) while <TXT>; 
        #print "[ELLI] $line \n";
        print $sock "PRIVMSG $channel : $line \r\n";
        close(TXT);
    }
}



