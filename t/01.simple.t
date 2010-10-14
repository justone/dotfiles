#!perl

use Test::More;
use strict;
use FindBin qw($Bin);

require "$Bin/helper.pl";

my $file_slurp_available = load_mod("File::Slurp qw(read_file)");

my @tests = (
    {   count => 11,
        code  => sub {
            my $t = 'simple';

            my ( $home, $repo ) = minimum_repo('simple');
            my $output = `HOME=$home perl $repo/bin/dfm --verbose`;

            ok( -d "$home/.backup", "$t - main backup dir exists" );
            ok( -l "$home/bin",     "$t - bin is a symlink" );
            ok( !-e "$home/.git",   "$t - .git does not exist in \$home" );
            ok( !-e "$home/.gitignore", "$t - .gitignore does not exist" );
            ok( !-l "$home/.ssh",       "$t - .ssh is not a symlink" );
            ok( !-e "$home/.ssh/.gitignore",
                "$t - .ssh/.gitignore does not exist" );
            is( readlink("$home/bin"), ".dotfiles/bin",
                "$t - bin points into repo" );
            ok( -d "$home/.ssh/.backup", "$t - ssh backup dir exists" );

        SKIP: {
                skip "File::Slurp not found", 1 unless $file_slurp_available;

                ok( read_file("$home/.bashrc") =~ /bashrc.load/,
                    "$t - loader present in bashrc" );
            }

            ok( !-e "$home/README.md", "$t - no README.md in homedir" );
            ok( !-e "$home/t",         "$t - no t dir in homedir" );

            }
    },
);

our $tests += $_->{count} for @tests;

plan tests => $tests;

$_->{code}->() for @tests;

