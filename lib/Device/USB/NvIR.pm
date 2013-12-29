package Device::USB::NvIR;

use 5.014;
use strict;
use warnings;

use Device::USB;
use MIME::Base64;
use Data::Dumper;

=head1 NAME

Device::USB::NvIR - interface to Nvidia's USB Infrared emitter for 3D Vision

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

This module interfaces with the 3D Vision gadget, allowing to load the required firmware (see below), and controlling over the ir emitter, frequency and switching.

    use Device::USB::NvIR;

    my $foo = Device::USB::NvIR->new();
    ...

=cut

sub new {
    my ($proto,%args) = @_;
    my $self = { %args };

    bless $self, ref($proto) || $proto;

    $self->{dev} = Device::USB->new->find_device(0x0955, 0x0007)
        or die "cannot find any nvidia usb device";

    unless($self->has_firmware) {
        $self->load_firmware
            or die "cannot load firmware";
    }

    $self->{dev}->set_configuration(1);
    $self->{dev}->claim_interface(0)
        and die "Cannot claim usb interface";

    return $self;
};

=head1 SUBROUTINES/METHODS

=head2 has_firmware

Returns 1 if the device has already loaded firmware

=cut

sub has_firmware {
    my ($self) = @_;

    return $self->_num_endpoints != 0;
}

=head2 load_firmware

=cut

sub load_firmware {
    my ($self, $data) = (@_);

    $data //= MIME::Base64::decode(join '', <DATA>)
        or return 0;

    say "Total firmware size: ".bytes::length $data;

    while( bytes::length($data) ) {
        my @m = unpack "C4a*", $data;
        $data = pop @m;
        my $s = shift(@m) << 8 | shift(@m);
        my $p = shift(@m) << 8 | shift(@m);
        @m = unpack "a${s}a*", $data;
        my $d = shift @m;
        $data = shift @m;
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

    $self->{dev} = Device::USB->new->find_device(0x0955, 0x0007)
        or die "cannot find any nvidia usb device";

    return $self->has_firmware;
}


#
## privates
#

sub _num_endpoints {
    my ($self) = @_;

    my $conf = ($self->{dev}->configurations->[0])
        or return 0;

    my $interface = ($conf->interfaces->[0][0])
        or return 0;

    say "We have ".$interface->bNumEndpoints." endpoints";

    return $interface->bNumEndpoints;
}

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
