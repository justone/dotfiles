#!perl

use Test::More;
use strict;
use FindBin qw($Bin);

require "$Bin/helper.pl";

my $file_slurp_available = load_mod("File::Slurp qw(read_file)");

my @tests = (
    {   count => 9,
        code  => sub {
            my $t = 'simplest';

            my ( $home, $repo ) = minimum_repo('simple');
            my $output = `HOME=$home perl $repo/bin/dfm --verbose`;

            ok( -d "$home/.backup", "$t - main backup dir exists" );
            ok( -l "$home/bin",     "$t - bin is a symlink" );
            ok( !-e "$home/.git",   "$t - .git does not exist in \$home" );
            ok( !-e "$home/.gitignore",  "$t - .gitignore does not exist" );
            ok( !-e "$home/.dfminstall", "$t - .dfminstall does not exist" );
            is( readlink("$home/bin"), ".dotfiles/bin",
                "$t - bin points into repo" );

        SKIP: {
                skip "File::Slurp not found", 1 unless $file_slurp_available;

                ok( read_file("$home/.bashrc") =~ /bashrc.load/,
                    "$t - loader present in bashrc" );
            }

            ok( !-e "$home/README.md", "$t - no README.md in homedir" );
            ok( !-e "$home/t",         "$t - no t dir in homedir" );
            }
    },
    {   count => 12,
        code  => sub {
            my $t = 'with .ssh recurse (no .ssh dir)';

            my ( $home, $repo ) = minimum_repo_with_ssh( 'ssh_no', 1 );
            my $output = `HOME=$home perl $repo/bin/dfm --verbose`;

            check_ssh_recurse( $t, $home );
            }
    },
    {   count => 12,
        code  => sub {
            my $t = 'with .ssh recurse (with .ssh dir)';

            my ( $home, $repo ) = minimum_repo_with_ssh('ssh_with');
            my $output = `HOME=$home perl $repo/bin/dfm --verbose`;

            check_ssh_recurse( $t, $home );
            }
    },
);

our $tests += $_->{count} for @tests;

plan tests => $tests;

$_->{code}->() for @tests;

sub check_ssh_recurse {
    my ( $t, $home ) = @_;
    ok( -d "$home/.backup",          "$t - main backup dir exists" );
    ok( -l "$home/bin",              "$t - bin is a symlink" );
    ok( !-e "$home/.git",            "$t - .git does not exist in \$home" );
    ok( !-e "$home/.gitignore",      "$t - .gitignore does not exist" );
    ok( !-e "$home/.dfminstall",     "$t - .dfminstall does not exist" );
    ok( !-l "$home/.ssh",            "$t - .ssh is not a symlink" );
    ok( !-e "$home/.ssh/.gitignore", "$t - .ssh/.gitignore does not exist" );
    is( readlink("$home/bin"), ".dotfiles/bin", "$t - bin points into repo" );
    ok( -d "$home/.ssh/.backup", "$t - ssh backup dir exists" );

SKIP: {
        skip "File::Slurp not found", 1 unless $file_slurp_available;

        ok( read_file("$home/.bashrc") =~ /bashrc.load/,
            "$t - loader present in bashrc" );
    }

    ok( !-e "$home/README.md", "$t - no README.md in homedir" );
    ok( !-e "$home/t",         "$t - no t dir in homedir" );
}
