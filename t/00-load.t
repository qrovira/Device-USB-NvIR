#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Device::USB::NvIR' ) || print "Bail out!\n";
}

diag( "Testing Device::USB::NvIR $Device::USB::NvIR::VERSION, Perl $], $^X" );
