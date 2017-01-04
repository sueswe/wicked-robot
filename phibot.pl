#!/usr/bin/env perl

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
my $version = "0.3 rc4";
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

print "Connecting to $server ... ";
my $sock = new IO::Socket::INET(
    PeerAddr => $server,
    PeerPort => $port,
    Proto => 'tcp') or die "Problem while creating socket: $! \n";
autoflush $sock 1;


### Login:
print $sock "NICK $nick\r\n";
print $sock "USER $login 8 * :Perl IRC Robot\r\n";

while (my $input = <$sock>) {
    if ($input =~ /004/) {
        # login completed.
        last;
    }
    elsif ($input =~ /433/) {
        die "Nickname \"$nick\" already in use! \n";
    }
}

### Greetings:
print $sock "MODE $nick +B \r\n"; # I am robot.
print $sock "JOIN $channel \r\n";
print $sock "PRIVMSG $channel : At your service. Ask me for help. (I am φbot version $version ) \r\n";


### Keep it alive:
while (my $input = <$sock>) {
    chomp($input);
    print "[IN] $input\n";
    if ($input =~ /^PING(.*)$/i) {
        # respond to PINGs to avoid disconnects.
        print $sock "PONG $1\r\n";
        # print $sock "PRIVMSG $channel :PONG :-) \r\n";
    }

    # <joined>
    elsif ( $input =~ m/JOIN/ig ) {
        joined("$input");
    }

    # <reload>
    elsif ($input =~ m/$nick/ig && $input =~ m/reload/ig ) {
        reload_actions();
    }

    # <actions>
    elsif ($input =~ m/$nick/ig && $input =~ m/action|aktion/ig ) {
        read_actions();
    }

    # <part>
    elsif ($input =~ m/$nick/ig && $input =~ m/leave/ig ) {
        part();
    }

    # <help>
    elsif ($input =~ m/$nick/ig && $input =~ m/help|hilf/ig ) {
        help();
    }

    # <beer>
    elsif ($input =~ m/bier|duff|seidl|hoibe|stiegl|zipfer|gösser/ig ) {
        beer("$input");
    }

    # <show us the rules>
    elsif ( $input =~ m/$nick/ig && $input =~ m/rules|laws|gesetze|regel/ig ) {
        show_rules();
    }

    # do something from <actions.rc>
    elsif ($input =~ m/$channel :$nick:/ig ) {
        execute("$input");
    }

    # <bueno fun>
    elsif ( $input =~ m/$nick/ig && $input =~ m/bueno/ig ) {
        print $sock "PRIVMSG $channel : I have no more buenos. They were all eaten by r2wurzro. :( \r\n";
    }

    # <question?>
    elsif ( $input =~ m/\?/ig ) {
        print "Someone asked me a question. Calling Elli for an answer.\n";
        elli();
    }

    # greeting
    elsif ( $input =~ m/hallo|hello/ig && $input =~ m/$nick/ig ) {
        greet("$input");
    }

    ### THAT'S ENOUGH. EVERYTHING ELSE WILL BE IGNORED.
    else {
        # ignored
    }
}



##############################################################################
#
# FUNCTIONS
#
##############################################################################

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
        print $sock "PRIVMSG $channel :Hello $you, welcome to $channel :) . I am (φ)$nick . I can help you. \r\n";
    }
}

sub greet {
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
        print $sock "PRIVMSG $channel :Hello $you . Whazup? \r\n";
    }
}

sub execute {
    # do something from actions.rc
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
        print $sock "PRIVMSG $channel :(sorry, I cannot find an operation for: $p You should write a script for it! :-) \r\n";
    } else {
        #print $sock "PRIVMSG $channel :$you: Ok, processing @T ... \r\n";
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
    print $sock "PRIVMSG $channel :                                                        rtc=$RTC .\r\n";
}

sub read_actions {
    print $sock "PRIVMSG $channel :Found following actions : \n\r";
    foreach my $g (sort keys %actions) {
        print "[INFO]: $g \t--> { $actions{$g} } \n";
        #print $sock "PRIVMSG $channel :Command $g = $actions{$g} \n\r";
        print $sock "PRIVMSG $channel :      $g      [ $actions{$g} ]\n\r";
    }
    print $sock "PRIVMSG $channel : Usage: phibot: <action>  (beware of the ':')\n\r";
}

sub part {
    print $sock "PART $channel :As you wish, master. \n";
    exit(100);
}

sub beer {
    my ($command) = @_;
    my @usersuche = split('!',$command);
    my $you = $usersuche[0];
    $you =~ s/://ig;
    print $sock "PRIVMSG $channel :$you, you can order beer at http://www.duff-shop.at/  \r\n";
}

sub help {
    print "Help called.\n";
    print $sock "PRIVMSG $channel :Well, maybe I can help you ... \r\n";
    print $sock "PRIVMSG $channel :  say \r\n";
    print $sock "PRIVMSG $channel :  $nick reload = reloading actions.rc (e.g. after updating actions.rc file) \r\n";
    print $sock "PRIVMSG $channel :  $nick actions  = show me the actions in the configfile \r\n";
    print $sock "PRIVMSG $channel :  $nick leave  = I will leave the server and exit \r\n";
    print $sock "PRIVMSG $channel :  $nick rules  = I will show you my rules \r\n";
    print $sock "PRIVMSG $channel :  $nick: <action>  = Start the action (beware of the ':' <-- IMPORTANT) \r\n";
    print $sock "PRIVMSG $channel :  $nick: My home is: http://sueswe.github.io/wicked-robot/ \r\n";

}

sub show_rules {
    print $sock "PRIVMSG $channel : A robot may not injure a human being or, through inaction, allow a human being to come to harm. \r\n";
    print $sock "PRIVMSG $channel : A robot must obey the orders given to it by human beings, except where such orders would conflict with the First Law. \r\n";
    print $sock "PRIVMSG $channel : A robot must protect its own existence as long as such protection does not conflict with the First or Second Law. \r\n";
    print $sock "PRIVMSG $channel : (http://en.wikipedia.org/wiki/Three_Laws_of_Robotics  -- This is _not_ from AI movie.) \r\n";
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
