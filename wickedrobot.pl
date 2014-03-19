#!/usr/bin/perl 

##############################################################################
#
# wicked-robot
#
# A robot for starting actions
# definded in a configurationfile,
# e.g. for deployment.
#
# (c) 2013 Werner Süß
#
##############################################################################

my $PORT = '7070';

##############################################################################

use warnings;
use strict;
use IO::Socket;
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init(
{
    level => $DEBUG,
    #level => $INFO,
    #level => $WARN,
    #level => $ERROR,
    #level => $FATAL,
    #file => ">> $logfile",
    file => 'stdout',
    mode => "append",
    layout => "%d %p> %m%n",
   }
);

my ($client,$request);
our (%actions);

##############################################################################

print "===================================================================\n";
print("$0 (c) 2012 Werner Süß\n");
INFO("loading actions ...");
require("actions.rc") || die("$!");

#foreach my $key (%actions) {
#    print "$actions{$key} \n";
#}


my $server = new IO::Socket::INET (
    LocalHost   => 'localhost',
    LocalPort   => $PORT,
    Proto       => 'tcp',
    Listen      => 10,
    Reuse       => 1,
    Type        => SOCK_STREAM,
) || die "Could not create socket: $!\n"; #unless $sock;

INFO("starting the server on port $PORT");

print "===================================================================\n";

while ($client = $server->accept()) {
    $request = <$client>;
    # print "$request \n";
    # print $client "answer\n";
    execute("$request");
    close $client;
}





##############################################################################

sub execute {
    my $command = shift;
    my $proc = $actions{$command};
    if ( ! defined $proc ) {
        DEBUG("nothing to do for $command");
    } else {
        INFO("Ich starte jetzt $proc");
        runcmd("$proc");
    }
    
}


sub runcmd {
    my (@command) = @_;
    open(FH,"-|","@command") || ERROR("Problem running [@command] ");
    while(<FH>) {
        my $out .= $_;
        my $timestamp = localtime();
        print "($timestamp): $out";
    }
    close(FH);
}












