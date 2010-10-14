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
    `mkdir -p $home/.ssh`;

    # create repo and copy in dfm
    `mkdir -p $repo/bin`;
    `mkdir -p $repo/t`;
    `mkdir -p $repo/.git`;
    `echo "ignore" > $repo/.gitignore`;
    `echo "readme contents" > $repo/README.md`;
    `mkdir -p $repo/.ssh`;
    `echo "sshignore" > $repo/.ssh/.gitignore`;
    `cp $Bin/../bin/dfm $repo/bin`;

    return ( $home, $repo );
}

sub load_mod {
    my $module_name_and_args = shift;

    eval "use $module_name_and_args";
    return !$@;
}
1;
