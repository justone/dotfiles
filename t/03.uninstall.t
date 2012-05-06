#!perl

use Test::More;
use strict;
use FindBin qw($Bin);
use English qw( -no_match_vars );

require "$Bin/helper.pl";

my $file_slurp_available = load_mod("File::Slurp qw(read_file)");

check_minimum_test_more_version();

my $profile_filename = ( lc($OSNAME) eq 'darwin' ) ? '.profile' : '.bashrc';

subtest 'uninstall dotfiles' => sub {
    focus('uninstall');

    my ( $home, $repo ) = minimum_home_with_ssh('uninstall');
    `touch $repo/.bashrc.load`;    # make sure there's a loader
    extra_setup($home);

    my $output;

    $output = `HOME=$home perl $repo/bin/dfm --verbose`;

    ok( -d "$home/.backup", 'main backup dir exists' );
    ok( -l "$home/bin",     'bin is a symlink' );

SKIP: {
        skip 'File::Slurp not found', 1 unless $file_slurp_available;

        ok( read_file("$home/$profile_filename") =~ /bashrc.load/,
            "loader present in $profile_filename" );
    }

    $output = `HOME=$home perl $repo/bin/dfm --verbose uninstall`;

    ok( !-l "$home/bin",            'bin is no longer a symlink' );
    ok( -e "$home/bin/preexisting", 'bin from backup is restored' );
    ok( -l "$home/.other",          'other symlink still exists' );

    ok( !-l "$home/.ssh/config", '.ssh/config is no longer a symlink' );
    ok( -e "$home/.ssh/config/preexisting",
        '.ssh/config from backup is restored'
    );

SKIP: {
        skip 'File::Slurp not found', 1 unless $file_slurp_available;

        ok( read_file("$home/$profile_filename") !~ /bashrc.load/,
            "loader absent in $profile_filename" );
    }
};

subtest 'uninstall dotfiles (dry-run)' => sub {
    focus('uninstall_dry');

    my ( $home, $repo ) = minimum_home_with_ssh('uninstall');
    `touch $repo/.bashrc.load`;    # make sure there's a loader
    extra_setup($home);

    my $output;

    $output = `HOME=$home perl $repo/bin/dfm --verbose`;

    ok( -d "$home/.backup", 'main backup dir exists' );
    ok( -l "$home/bin",     'bin is a symlink' );

SKIP: {
        skip 'File::Slurp not found', 1 unless $file_slurp_available;

        ok( read_file("$home/$profile_filename") =~ /bashrc.load/,
            "loader present in $profile_filename" );
    }

    $output = `HOME=$home perl $repo/bin/dfm --dry-run --verbose uninstall`;

    ok( -l "$home/bin", 'bin is still a symlink' );

    ok( -l "$home/.ssh/config", '.ssh/config is still a symlink' );

SKIP: {
        skip 'File::Slurp not found', 1 unless $file_slurp_available;

        ok( read_file("$home/$profile_filename") =~ /bashrc.load/,
            "loader still exists in $profile_filename"
        );
    }
};

done_testing;

sub extra_setup {
    my $home = shift;

    symlink( "/anywhere/else", "$home/.other" );
    mkdir("$home/.backup");
    mkdir("$home/.backup/bin");
    mkdir("$home/.backup/bin/preexisting");
    mkdir("$home/.ssh/.backup");
    mkdir("$home/.ssh/.backup/config");
    mkdir("$home/.ssh/.backup/config/preexisting");
}
