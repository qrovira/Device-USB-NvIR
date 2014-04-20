# NAME

Device::USB::NvIR - Interface to Nvidia 3D vision USB infrared emitter

# VERSION

Version 0.01

# SYNOPSIS

This module interfaces with the device using [Device::USB](https://metacpan.org/pod/Device::USB), and allows to load
the required firmware (see below), control frequency and switching.

    use Device::USB::NvIR;

    my $foo = Device::USB::NvIR->new( rate => 100 );

    $foo->swap_eye("right");
    $foo->swap_eye("left");

# SUBROUTINES/METHODS

## load\_firmware($binary\_data)

Attempt to load the firmware required by the USB device.
This is already attempted during initialization.

## set\_rate($rate)

Set the controller refresh rate

## set\_eye($eye)

Set eye

## swap\_eye($eye)

Swap eye (dummy placeholder for sync foolness)

# WHY???

Yes, interfacing such device from Perl might be stupid, but I wanted to use the
emitter for the wiimote on the living room computer, regardless of being on 3D
mode or not, and the syncing part of the tools i found were bound to the display

Refer to the libnvstusb project on which this module was based on for much more
detail.

# TODO

I could already fulfill my need, but for fun, there's other parts of the library
that could be ported. Someone crazy enough might glue this up with the [OpenGL](https://metacpan.org/pod/OpenGL)
modules...

# CAVEATS

As you can read on Bob Somer's article, Linux will set the default permissions to
unknown USB devices to read-only, so in order to be able to use this module from
a non-root user, you'll probably need to add something like the following to your
udev rules:

    SUBSYSTEM=="usb", ATTR{idVendor}=="0955", ATTR{idProduct}=="0007", MODE="0666"

# SAMPLE USB CAPTURE

This is easy to get with a simple `modprobe usbmon` and some fiddling around
/sys/kernel/debug/usb/usbmon/\*, but for the curious (like I was)

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

# REFERENCES

This little piece of crap is based on proper research done by Bob Sanders and the libnvstusb
folks, where you'll find much better implementation details.

- [Bob Somer's article](http://users.csc.calpoly.edu/~zwood/teaching/csc572/final11/rsomers/)

    Listing this one first for the sole reason it was the first one I found and started messing with.
    I actually found it fun how he describes his \*process\* on how he solved the issues he found, rather
    than just the plain solution.

- [libnvstusb project on SourceForge](http://sourceforge.net/projects/libnvstusb/)

    The real beef. This C library implements (i guess) as much as they could find out about the device.
    The comments on the code are smart and clear.

# AUTHOR

Quim Rovira, `<met at cpan.org>`

# BUGS

Please report any bugs or feature requests to `bug-device-usb-nvir at rt.cpan.org`, or through
the web interface at [http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Device-USB-NvIR](http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Device-USB-NvIR).  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

# SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Device::USB::NvIR

You can also look for information at:

- Github

    [http://github.com/dist/Device-USB-NvIR/](http://github.com/dist/Device-USB-NvIR/)

# ACKNOWLEDGEMENTS

Based on [libnvstusb](http://sourceforge.net/projects/libnvstusb), which is a proper C implementation meant to be used for stereoscopic vision.

All NVIDIA specific material, trademarks, and firmwares in this proof of concept is their property.

# LICENSE AND COPYRIGHT

Copyright 2013 Quim Rovira.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.
