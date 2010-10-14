#!/usr/bin/perl

use strict;
use warnings;

sub minimum_repo {
    my $name = shift;

    my $home = "$Bin/$name";
    my $repo = "$home/.dotfiles";

    # clear out old test area
    `rm -rf $home`;

    # create homedir
    `mkdir -p $home`;

    # create repo and copy in dfm
    `mkdir -p $repo/bin`;
    `echo "README.md skip\nt skip" > $repo/.dfminstall`;
    `mkdir -p $repo/t`;
    `mkdir -p $repo/.git`;
    `echo "ignore" > $repo/.gitignore`;
    `echo "readme contents" > $repo/README.md`;
    `cp $Bin/../bin/dfm $repo/bin`;

    return ( $home, $repo );
}

sub minimum_repo_with_ssh {
    my $name = shift;
    my $skip_home_ssh_dir = shift || 0;

    my ( $home, $repo ) = minimum_repo($name);

    `mkdir -p $home/.ssh` if !$skip_home_ssh_dir;

    # create repo and copy in dfm
    `echo ".ssh" >> $repo/.dfminstall`;
    `mkdir -p $repo/.ssh`;
    `echo "sshignore" > $repo/.ssh/.gitignore`;

    return ( $home, $repo );
}

sub load_mod {
    my $module_name_and_args = shift;

    eval "use $module_name_and_args";
    return !$@;
}
1;
