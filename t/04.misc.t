#!perl

use Test::More;
use strict;
use FindBin qw($Bin);

use Test::Trap qw/ :output(systemsafe) /;

require "$Bin/helper.pl";

my $version = '0.5';

check_minimum_test_more_version();

subtest 'help works on all subcommands' => sub {
    focus('help');

    my ( $home, $repo ) = minimum_home('help');

    foreach my $command (qw(install mergeandinstall updates)) {
        run_dfm( $home, $repo, $command, '--help' );
        like(
            $trap->stdout,
            qr/Usage.*For full documentation/msi,
            "help ok for subcommand $command"
        );
        like(
            $trap->stdout,
            qr/dfm version $version/msi,
            "version number ok"
        );
    }
};

subtest 'version commandline flag' => sub {
    focus('version');

    my ( $home, $repo ) = minimum_home('version');

    run_dfm( $home, $repo, '--version' );
    like( $trap->stdout, qr/dfm version $version/msi, "version output ok" );
};

done_testing;
