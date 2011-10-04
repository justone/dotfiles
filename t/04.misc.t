#!perl

use Test::More;
use strict;
use FindBin qw($Bin);

require "$Bin/helper.pl";

subtest 'help works on all subcommands' => sub {
    my ( $home, $repo ) = minimum_home('help');

    foreach my $command (qw(install mergeandinstall updates)) {
        my $output = `HOME=$home perl $repo/bin/dfm $command --help`;
        like(
            $output,
            qr/Usage.*For full documentation/msi,
            "help ok for subcommand $command"
        );
    }
};

done_testing;
