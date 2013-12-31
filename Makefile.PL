use 5.014;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Device::USB::NvIR',
    AUTHOR              => q{Quim Rovira <met@cpan.org>},
    VERSION_FROM        => 'lib/Device/USB/NvIR.pm',
    ABSTRACT_FROM       => 'lib/Device/USB/NvIR.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
        'Device::USB' => '0.36',
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Device-USB-NvIR-*' },
    EXE_FILES => [ 'bin/dun-tool' ],
);
