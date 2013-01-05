#!/usr/bin/perl

##############################################################################
#
# 
#
##############################################################################

use warnings;
use strict;
use IO::Socket;

my $message = $ARGV[0];

if (! defined $message) { print "No message given.\n"; exit(1); }


my $sock = new IO::Socket::INET (
    PeerAddr => 'localhost',
    PeerPort => '7070',
    Proto => 'tcp',
    Type => SOCK_STREAM,
) || die "Could not create socket: $!\n";  #unless $sock;
print $sock "$message";
close($sock);


