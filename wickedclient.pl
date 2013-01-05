#!/usr/bin/perl

##############################################################################
#
# 
#
##############################################################################

use warnings;
use strict;
use IO::Socket;

my $sock = new IO::Socket::INET (
    PeerAddr => 'localhost',
    PeerPort => '7070',
    Proto => 'tcp',
    Type => SOCK_STREAM,
) || die "Could not create socket: $!\n";  #unless $sock;
print $sock "deploy test";
close($sock);


