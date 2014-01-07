package Device::USB::NvIR;

use 5.014;
use strict;
use warnings;

use Device::USB;
use MIME::Base64;
use Time::HiRes;
use Data::Dumper;

=head1 NAME

Device::USB::NvIR - interface to Nvidia 3D vision USB infrared emitter

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

This module interfaces with the device using L<Device::USB>, and allows to load
the required firmware (see below), control frequency and switching.

    use Device::USB::NvIR;

    my $foo = Device::USB::NvIR->new( rate => 100 );

    $foo->swap_eye("right");
    $foo->swap_eye("left");

=cut

sub new {
    my ($proto,%args) = @_;
    my $self = {
        rate => 75.024675,
        eye  => "quad",
        invert_eyes => 0,
#        vblank_method => 0,
#        toggled_3d => 0,
        %args
    };

    bless $self, ref($proto) || $proto;

    $self->{dev} = Device::USB->new->find_device(0x0955, 0x0007)
        or die "cannot find any nvidia usb device";

    unless($self->_endpoints) {
        $self->load_firmware
            or die "cannot load firmware";
    }

    $self->{dev}->set_configuration(1);
    $self->{dev}->claim_interface(0)
        and die "Cannot claim usb interface";

    $self->set_rate( $self->{rate} );
    $self->set_eye( $self->{eye} );

    return $self;
};

=head1 SUBROUTINES/METHODS

=head2 load_firmware($binary_data)

Attempt to load the firmware required by the USB device.
This is already attempted during initialization.

=cut

sub load_firmware {
    my ($self, $data) = (@_);

    $data //= MIME::Base64::decode(join '', <DATA>)
        or return 0;

    say "Total firmware size: ".bytes::length $data;

    while( bytes::length($data) ) {
        my ($s, $p, $d);

        # Unpack size, position.. can't use n/a since it's the wrong order (?)
        ($s, $p, $data) = unpack "nna*", $data;
        # Now fetch the next $s bytes for this firmware module
        ($d, $data) = unpack "a${s}a*", $data;

        say "Processing fw module at pos $p, total of $s / ".bytes::length($d)." bytes, ".bytes::length($data)." bytes left.";
        my $ret = $self->{dev}->control_msg(
            (0x02 << 5), # USB_TYPE_VENDOR as in usb.h, not on Device::USB
            0xA0,        # Firmware load
            $p,          # uhm.. pos
            0x0000,      # uhm.. more
            $d,          # swallow this!
            $s,
            0
        );

        return 0 unless $ret >= 0;
    }

    # reconnect
    $self->{dev}->reset;

    usleep(50000);

    $self->{dev} = Device::USB->new->find_device(0x0955, 0x0007)
        or die "cannot find any nvidia usb device";

    return $self->_endpoints > 0;
}

=head2 set_rate($rate)

Set the controller refresh rate

=cut
sub set_rate {
    my ($self, $rate) = @_;

    die "can't set rate to $rate"
        unless $rate >= 60 && $rate <= 120;

    $self->{rate} = $rate;

    $self->_command( 2, "write", 0x00,
        # db29ffff 68b5ffff 81dfffff 30282422 0a080504 418ffdff
        pack "V3C8V",
            NVSTUSB_T2_COUNT(4568.50),
            NVSTUSB_T0_COUNT(4774.25),
            NVSTUSB_T0_COUNT(2080),
            0x30, 0x28, 0x24, 0x22, # IR pattern / would it burn with constant 1/1 ?
            0x0a, 0x08, 0x05, 0x04, # just ?
            NVSTUSB_T2_COUNT(1000000.0/$rate),
    );

    # Set 0x1c to 2 (?)
    $self->_command( 2, "write", 0x1c, pack "v", 2 );

    # Set the timeout
    $self->_command( 2, "write", 0x1e, pack "v", $rate * 4 );

    # Set 0x1b to 7 (?)
    $self->_command( 2, "write", 0x1b, pack "C", 7 );
}

=head2 set_eye($eye)

Set eye

=cut
sub set_eye {
    my ($self, $eye) = @_;

    $self->{eye} = $eye;

    if( $eye eq "quad" ) {
        $self->set_eye("left");
        $self->set_eye("right");
    } else {
        my $eye_id = ( $eye eq "right" ? 1 : 0 ) ^ $self->{invert_eyes} ? 0xff : 0xfe;
        $self->_command( 1, "set_eye", $eye_id,
            pack "V",
                NVSTUSB_T2_COUNT((1e6/$self->{rate})/1.8)
        );
    }

}

=head2 swap_eye($eye)

Swap eye (dummy placeholder for sync foolness)

=cut
sub swap_eye {
    my ($self, $eye) = @_;

    # dare to integrate with pogl? :P
    $self->set_eye(
        $eye // (
            $self->{eye} eq "right" ? "left" :
            $self->{eye} eq "left" ? "right" : "quad"
        )
    );
}


#
## privates, usb stuffs
#

sub NVSTUSB_T0_CLOCK() { 48e6 / 12 }
sub NVSTUSB_T0_COUNT($) { (-($_[0])*(NVSTUSB_T0_CLOCK/1e6)+1) }
sub NVSTUSB_T0_US($) { (-($_[0]-1)/(NVSTUSB_T0_CLOCK/1e6)) }

sub NVSTUSB_T2_CLOCK() { 48e6 / 4 }
sub NVSTUSB_T2_COUNT($) { (-($_[0])*(NVSTUSB_T2_CLOCK/1e6)+1) }
sub NVSTUSB_T2_US($) { (-($_[0]-1)/(NVSTUSB_T2_CLOCK/1e6)) }

# this crap is for debugging
sub _hexdump {
    return join '', map { 
        my $o='';
        my @h=(0..9,'a'..'z');
        do { $o=$h[$_%16].$o; $_=int($_/16); } while $_;
        $o;
    } unpack 'C*', shift;
}

sub _command {
    my ($self, $endpoint, $command, $address, $data ) = @_;

    my $cmd = $command eq "write" ? 1 :
        $command eq "read"  ? 2 :
        $command eq "clear" ? 40 :
        $command eq "set_eye" ? 0xaa :
        $command eq "x0199" ? 0xbe :
        die "invalid command $command";

    my $buf = pack "CCv/a", $cmd, $address, $data;

    #say sprintf "[debug] $command to $endpoint: %s", _hexdump($buf);

    return $self->{dev}->bulk_write( $endpoint, $buf, bytes::length($buf), 0 ) >= 0;
}


sub _endpoints {
    my ($self) = @_;

    my $conf = ($self->{dev}->configurations->[0])
        or return 0;

    my $interface = $conf->interfaces->[0][0]
        or return 0;

    return @{ $interface->endpoints // [] };
}

=head1 WHY???

Yes, interfacing such device from Perl might be stupid, but I wanted to use the
emitter for the wiimote on the living room computer, regardless of being on 3D
mode or not, and the syncing part of the tools i found were bound to the display

Refer to the libnvstusb project on which this module was based on for much more
detail.

=head1 TODO

I could already fulfill my need, but for fun, there's other parts of the library
that could be ported. Someone crazy enough might glue this up with the L<OpenGL>
modules...

=head1 CAVEATS

As you can read on Bob Somer's article, Linux will set the default permissions to
unknown USB devices to read-only, so in order to be able to use this module from
a non-root user, you'll probably need to add something like the following to your
udev rules:

  SUBSYSTEM=="usb", ATTR{idVendor}=="0955", ATTR{idProduct}=="0007", MODE="0666"

=head1 SAMPLE USB CAPTURE

This is easy to get with a simple C<modprobe usbmon> and some fiddling around
/sys/kernel/debug/usb/usbmon/*, but for the curious (like I was)

  ffff8801bd5e9240 2162701228 S Co:019:00 s 00 09 0001 0000 0000 0
  ffff8801bd5e9240 2162701446 C Co:019:00 0 0
  ffff8801fdbe3240 2162701833 S Bo:019:02 -115 28 = 01001800 db29ffff 68b5ffff 81dfffff 30282422 0a080504 418ffdff
  ffff8801fdbe3240 2162701971 C Bo:019:02 0 28 >
  ffff8801fdbe3240 2162701998 S Bo:019:02 -115 6 = 011c0200 0200
  ffff8801fdbe3240 2162702097 C Bo:019:02 0 6 >
  ffff8801f70e2480 2162702127 S Bo:019:02 -115 6 = 011e0200 2c01
  ffff8801f70e2480 2162702194 C Bo:019:02 0 6 >
  ffff8801f70e2480 2162702206 S Bo:019:02 -115 5 = 011b0100 07
  ffff8801f70e2480 2162702348 C Bo:019:02 0 5 >
  ffff8801bd5e9000 2162721059 S Bo:019:01 -115 8 = aafe0000 e6a4feff
  ffff8801bd5e9000 2162721201 C Bo:019:01 0 8 >
  ffff8801f70e2a80 2162721237 S Bo:019:01 -115 8 = aaff0000 e6a4feff
  ffff8801f70e2a80 2162721331 C Bo:019:01 0 8 >
  ffff8801f70e2a80 2162721394 S Bo:019:02 -115 4 = 42180300
  ffff8801f70e2a80 2162721444 C Bo:019:02 0 4 >
  ffff8801f70e2a80 2162721501 S Bi:019:04 -115 7 <
  ffff8801f70e2a80 2162921727 C Bi:019:04 -2 0
  ffff8801bd5e9180 2162934303 S Bo:019:01 -115 8 = aafe0000 e6a4feff
  ffff8801bd5e9180 2162934477 C Bo:019:01 0 8 >
  ffff8801f70e2180 2162934535 S Bo:019:01 -115 8 = aaff0000 e6a4feff
  ffff8801f70e2180 2162934587 C Bo:019:01 0 8 >
  ffff8801bd5e9a80 2162960987 S Bo:019:01 -115 8 = aafe0000 e6a4feff
  ffff8801bd5e9a80 2162961075 C Bo:019:01 0 8 >
  ffff8801f70e2180 2162961135 S Bo:019:01 -115 8 = aaff0000 e6a4feff
  ffff8801f70e2180 2162961357 C Bo:019:01 0 8 >
  ffff8801bd5e9840 2162987663 S Bo:019:01 -115 8 = aafe0000 e6a4feff
  ffff8801bd5e9840 2162987700 C Bo:019:01 0 8 >
  ffff8801bd5e9840 2162987721 S Bo:019:01 -115 8 = aaff0000 e6a4feff


=head1 REFERENCES

This little piece of crap is based on proper research done by Bob Sanders and the libnvstusb
folks, where you'll find much better implementation details.

=over

=item L<http://users.csc.calpoly.edu/~zwood/teaching/csc572/final11/rsomers/|Bob Somer's article>

Listing this one first for the sole reason it was the first one I found and started messing with.
I actually found it fun how he describes his *process* on how he solved the issues he found, rather
than just the plain solution.

=item L<http://sourceforge.net/projects/libnvstusb/|libnvstusb project on SourceForge>

The real beef. This C library implements (i guess) as much as they could find out about the device.
The comments on the code are smart and clear.

=back


=head1 AUTHOR

Quim Rovira, C<< <met at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-device-usb-nvir at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Device-USB-NvIR>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Device::USB::NvIR


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Device-USB-NvIR>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Device-USB-NvIR>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Device-USB-NvIR>

=item * Search CPAN

L<http://search.cpan.org/dist/Device-USB-NvIR/>

=back


=head1 ACKNOWLEDGEMENTS

Based on L<libnvstusb|http://sourceforge.net/projects/libnvstusb>, which is a proper C implementation meant to be used for stereoscopic vision.

All NVIDIA specific material, trademarks, and firmwares in this proof of concept is their property.


=head1 LICENSE AND COPYRIGHT

Copyright 2013 Quim Rovira.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Device::USB::NvIR
__DATA__
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
4Pq6AgMCFdSQ5qDg+kQB8AIV1JDmvOD6UwJ+kOa84PvDdICb5DNKkBfok/ozleD7dKEq+nTmO/uQ
5rzg/FMEfpDmvOD9w3SAneQzTJAX6JP8M5Xg/XShLPx05j39jIKNg+D8QwQBioKLg+zwgBeQ5qDg
+kQB8IANEg3rUAiQ5qDg+kQB8JDmoOBEgPAiU9jvMjAKCpDmgOD6RArwgAiQ5oDg+kQI8JAB9BIW
SZDmXXT/8JDmX3T/8FOR75DmgOBU9/AiqoKrQ6xEi4KMg6Pg/b0DI4oFGu1wBYuCjIMiiwWMBouC
jIPg/3gA7y396D7+jQOOBIDTkAAAIqqCq4OQ5gDg/FQYcBF0ASr85Dv9jALDE8oTyvuAEpDmAOD8
UwQYvBAH68ol4Moz+4oEiwUauv8BG+xNYA3AAsADEgtM0APQAoDmIpDmguD6MOAIkOaC4Pog5hCQ
5oLg+jDhHZDmguD6MOcVkOaA4EQB8JAAFBIWSZDmgOD6VP7wIvt6IOT8/f7/5YIlgvWC5YMz9YPl
8DP18Osz+0AX2umAQuWCJYL1guWDM/WD5fAz9fDrM/vsM/ztM/3uM/7vM//slRztlR3ulR7vlR9A
E+yVHPztlR397pUe/u+VH/9DggHavusi+8LVMOcV0tXkw5WC9YLklYP1g+SV8PXw5Jv75R8w5xey
1eTDlRz1HOSVHfUd5JUe9R7klR/1H+sSFsow1RP75MOVgvWC5JWD9YPklfD18OSbIiD3FDD2FIiD
qIIg9QfmqIN1gwAi4oD35JMi4CJ1ggAiIE5WSURJQSBmaXJtd2FyZSAyNTguNDkgSnVuICA5IDIw
MTAgMTA6MzM6MjcAxLCcgFwsAAgEDAAB/wD/AAABAQAA/wD/AQAAAQICAwMEBAUFAAAAAAAAAAAA
AAAABPz//wFkHQASAQACAAAAQFUJBwAAAwECAAEKBgACAAAAQAEACQIuAAEBAIDICQQAAAT/AAAA
BwUBAgACAQcFgQNAAAEHBQICAAIABwWEAgACAQkHLgABAQCAyAkEAAAE/wAAAAcFAQIAAgEHBYED
QAABBwUCAgACAQcFhAIAAgEJAi4AAQEAgMgJBAAABP8AAAAHBQECQAABBwWBA0AAAQcFAgJAAAAH
BYQCQAABCQcuAAEBAIDICQQAAAT/AAAABwUBAkAAAQcFgQNAAAEHBQICQAABBwWEAkAAAQQDCQRM
A0MAbwBwAHkAcgBpAGcAaAB0ACAAKABjACkAIAAyADAAMQAwACAATgBWAEkARABJAEEAIABDAG8A
cgBwAG8AcgBhAHQAaQBvAG4AMgNOAFYASQBEAEkAQQAgAHMAdABlAHIAZQBvACAAYwBvAG4AdABy
AG8AbABsAGUAcgACAwoDTgBWAEQAQQAAAAC4HwACDe0AAg4bAAIOBQACDm0AAg4xAAIOhQACDsEA
Ag7CAAIOwwACDsQAAg7FAAIOxgACD4gAAhEYAAIRGQACERoAAhEbAAIOwgACERwAAhEdAAIRHgAC
ER8AAhEgAAIRIQACESIAAg7CAAIOwgACDsIAAhEjAAIRJAACESUAAhEmAAIRJwACESgAAhEpAAIR
KgACESsAAhEsAAIRLQACES4AAhEvAAIRMAACETEAAhEyAAIRMwACETQAAAHmAAA=
