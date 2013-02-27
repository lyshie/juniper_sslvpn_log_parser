#!/usr/bin/env perl

#===============================================================================
#
#         FILE: ae_vpn_log_parser.pl
#
#        USAGE: ./ae_vpn_log_parser.pl
#
#  DESCRIPTION: Initial testing parser for Juniper SSL-VPN log file
#
#      OPTIONS: ---
# REQUIREMENTS: JuniperSSLVPN.pm
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: SHIE, Li-Yi <lyshie@mx.nthu.edu.tw>
# ORGANIZATION:
#      VERSION: 1.0
#      CREATED: 2013/02/27 15:20:00
#     REVISION: ---
#===============================================================================

use strict;
use warnings;

use FindBin qw($Bin);
use File::Basename;
use AnyEvent;
use AnyEvent::Handle;
use autodie 'open';
use lib "$Bin";
use JuniperSSLVPN;

$| = 1;

my $cv = AnyEvent->condvar;

my $SELF = "$Bin/" . basename($0);
my @ARGS = @ARGV;

# Read
my $fh;
open( $fh, '<', $ARGV[0] );

my $handle = create_handle();

# tail -f like mode
sub create_handle {
    AnyEvent::Handle->new(
        fh       => $fh,
        on_error => sub {
            my ( $h, $fatal, $message ) = @_;
            $h->destroy();
            undef($h);
            $cv->send();
        },
        on_eof => sub {
            $handle->destroy();
            undef($handle);
            $handle = create_handle();
        },
        on_read => sub {
            my ($h) = @_;
            $h->push_read(
                line => sub {
                    my ( $h, $line ) = @_;
                    JuniperSSLVPN::parse_line($line);
                }
            );
        },
    );
}

# Process INT signal and finalize
my $signal;
$signal = AnyEvent->signal(
    signal => "INT",
    cb     => sub {
        print "Exiting...\n";
        $handle->destroy();
        undef($handle);
        $cv->send();
    },
    signal => "HUP",
    cb     => sub {
        print "Restarting...\n";
        $handle->destroy();
        undef($handle);
        $cv->send();

        exec $SELF => @ARGS;
        die("Couldn't exec $SELF => @ARGS\n");
    },
);

# Main Loop
$cv->recv();
