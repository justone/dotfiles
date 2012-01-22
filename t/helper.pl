#!/usr/bin/perl

use strict;
use warnings;
use FindBin qw($Bin);
use Test::More;

sub simple_repo {
    my $name = shift;

    my $repo = "$Bin/${name}_repo";

    # clean up
    `rm -rf $repo`;
    `rm -rf $repo.git`;

    `mkdir -p $repo/bin`;
    `echo "README.md skip\nt skip" > $repo/.dfminstall`;
    `mkdir -p $repo/t`;
    `echo "ignore" > $repo/.gitignore`;
    `echo "readme contents" > $repo/README.md`;
    `cp $Bin/../bin/dfm $repo/bin`;

    chdir($repo);
    `git init`;
    `git add .`;
    `git commit -m 'initial commit'`;
    chdir($Bin);
    `git clone --bare $repo $repo.git`;
    `rm -rf $repo`;

    return "$repo.git";
}

sub minimum_home {
    my $name = shift;
    my $origin_repo_path = shift || simple_repo($name);

    my $home = "$Bin/$name";
    my $repo = "$home/.dotfiles";

    # clear out old test area
    `rm -rf $home`;

    # create homedir
    `mkdir -p $home`;

    `git clone file://$origin_repo_path $repo`;

    return ( $home, $repo, $origin_repo_path );
}

sub minimum_home_with_ssh {
    my $name = shift;
    my $skip_home_ssh_dir = shift || 0;

    my ( $home, $repo ) = minimum_home($name);

    `mkdir -p $home/.ssh` if !$skip_home_ssh_dir;

    # create repo and copy in dfm
    `echo ".ssh" >> $repo/.dfminstall`;
    `mkdir -p $repo/.ssh`;
    `mkdir -p $repo/.ssh/config`;
    `echo "sshignore" > $repo/.ssh/.gitignore`;

    return ( $home, $repo );
}

sub load_mod {
    my $module_name_and_args = shift;

    eval "use $module_name_and_args";
    return !$@;
}

sub check_minimum_test_more_version {
    if ( $Test::More::VERSION < 0.98 ) {
        plan skip_all => 'Test::More version 0.98 required';
    }
}
1;
