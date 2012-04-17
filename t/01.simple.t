#!perl

use Test::More;
use strict;
use FindBin qw($Bin);
use English qw( -no_match_vars );

require "$Bin/helper.pl";

my $file_slurp_available = load_mod('File::Slurp qw(read_file)');

check_minimum_test_more_version();

my $profile_filename = ( lc($OSNAME) eq 'darwin' ) ? '.profile' : '.bashrc';

subtest 'simplest' => sub {
    focus('simplest');

    my ( $home, $repo, $origin );
    ( $home, $repo, $origin ) = minimum_home('simple');
    ( $home, $repo ) = minimum_home( 'simple2', { origin => $origin } );
    my $output = `HOME=$home perl $repo/bin/dfm --verbose`;

    ok( -d "$home/.backup",      'main backup dir exists' );
    ok( -l "$home/bin",          'bin is a symlink' );
    ok( !-e "$home/.git",        ".git does not exist in \$home" );
    ok( !-e "$home/.gitignore",  '.gitignore does not exist' );
    ok( !-e "$home/.dfminstall", '.dfminstall does not exist' );
    is( readlink("$home/bin"), '.dotfiles/bin', 'bin points into repo' );

SKIP: {
        skip 'File::Slurp not found', 1 unless $file_slurp_available;

        ok( read_file("$home/$profile_filename") =~ /bashrc.load/,
            "loader present in $profile_filename" );
    }

    ok( !-e "$home/README.md", 'no README.md in homedir' );
    ok( !-e "$home/t",         'no t dir in homedir' );
};

subtest 'dangling symlinks' => sub {
    focus('dangling');

    my ( $home, $repo ) = minimum_home_with_ssh('dangling');

    symlink( ".dotfiles/.other",         "$home/.other" );
    symlink( "../.dotfiles/.ssh/.other", "$home/.ssh/.other" );

    my $output = `HOME=$home perl $repo/bin/dfm --verbose`;

    ok( !-l "$home/.other",      'dangling symlink is gone' );
    ok( !-l "$home/.ssh/.other", 'dangling symlink is gone' );
};

subtest 'with . ssh recurse( no . ssh dir )' => sub {
    focus('recurse_no');

    my ( $home, $repo ) = minimum_home_with_ssh( 'ssh_no', 1 );
    my $output = `HOME=$home perl $repo/bin/dfm --verbose`;

    check_ssh_recurse($home);
};

subtest 'with .ssh recurse (with .ssh dir)' => sub {
    focus('recurse_with');

    my ( $home, $repo ) = minimum_home_with_ssh('ssh_with');
    my $output = `HOME=$home perl $repo/bin/dfm --verbose`;

    check_ssh_recurse($home);
};

subtest 'with bin recurse' => sub {
    focus('bin_recurse');

    my ( $home, $repo, $origin );
    ( $home, $repo, $origin )
        = minimum_home( 'bin_recurse', { dfminstall_contents => 'bin' } );

    `mkdir -p $home/bin`;
    `echo "another bin" > $home/bin/another`;

    my $output = `HOME=$home perl $repo/bin/dfm --verbose`;

    ok( -d "$home/.backup", 'main backup dir exists' );
    ok( -d "$home/bin",     'bin is a directory' );
    ok( -l "$home/bin/dfm", 'dfm is a symlink' );
    ok( -e "$home/bin/another" && !-l "$home/bin/another",
        'existing binary still intact' );
};

subtest 'check deprecated recursion' => sub {
    focus('deprec');

    my ( $home, $repo );

    ( $home, $repo )
        = minimum_home( 'deprecated_recurse',
        { dfminstall_contents => 'bin' } );

    my $output = `HOME=$home perl $repo/bin/dfm --verbose`;
    like(
        $output,
        qr(using implied recursion in .dfminstall is deprecated),
        'warning present'
    );
    like( $output, qr($repo/.dfminstall), '.dfminstall path present' );
    like(
        $output,
        qr('bin recurse'),
        'proper .dfminstall contents mentioned'
    );

    ( $home, $repo )
        = minimum_home( 'deprecated_recurse',
        { dfminstall_contents => 'bin recurse' } );

    my $output = `HOME=$home perl $repo/bin/dfm --verbose`;
    unlike(
        $output,
        qr(using implied recursion in .dfminstall is deprecated),
        'warning present when keyword used'
    );

};

subtest 'switch to recursion' => sub {
    focus('rec_switch');

    my ( $home, $repo, $origin );
    ( $home, $repo, $origin ) = minimum_home('switch_recurse');

    my $output;

    $output = `HOME=$home perl $repo/bin/dfm --verbose`;

    ok( -d "$home/.backup", 'main backup dir exists' );
    ok( -l "$home/bin",     'bin is a symlink' );

    `echo "bin recurse" >> $repo/.dfminstall`;

    $output = `HOME=$home perl $repo/bin/dfm --verbose`;

    ok( -d "$home/.backup", 'main backup dir exists' );
    ok( -d "$home/bin",     'bin is a directory' );
    ok( -l "$home/bin/dfm", 'dfm is a symlink' );
};

subtest 'parallel recursions work' => sub {
    focus('parallel_rec');

    my ( $home, $repo, $origin );
    ( $home, $repo, $origin )
        = minimum_home( 'parallel_recursions',
        { dfminstall_contents => "test1 recurse\ntest2 recurse" } );

    `mkdir -p $repo/test1`;
    `touch $repo/test1/file1`;
    `mkdir -p $repo/test2`;
    `touch $repo/test2/file2`;

    my $output = `HOME=$home perl $repo/bin/dfm --verbose`;

    ok( -d "$home/test1",       'first directory present' );
    ok( -l "$home/test1/file1", 'first file is symlink' );
    ok( -d "$home/test2",       'second directory present' );
    ok( -l "$home/test2/file2", 'second file is symlink' );
};

done_testing;

sub check_ssh_recurse {
    my ($home) = @_;
    ok( -d "$home/.backup",          'main backup dir exists' );
    ok( -l "$home/bin",              'bin is a symlink' );
    ok( !-e "$home/.git",            '.git does not exist in $home' );
    ok( !-e "$home/.gitignore",      '.gitignore does not exist' );
    ok( !-e "$home/.dfminstall",     '.dfminstall does not exist' );
    ok( !-l "$home/.ssh",            '.ssh is not a symlink' );
    ok( !-e "$home/.ssh/.gitignore", '.ssh/.gitignore does not exist' );
    is( readlink("$home/bin"), '.dotfiles/bin', 'bin points into repo' );
    ok( -d "$home/.ssh/.backup", 'ssh backup dir exists' );

SKIP: {
        skip 'File::Slurp not found', 1 unless $file_slurp_available;

        ok( read_file("$home/$profile_filename") =~ /bashrc.load/,
            "loader present in $profile_filename" );
    }

    ok( !-e "$home/README.md", 'no README.md in homedir' );
    ok( !-e "$home/t",         'no t dir in homedir' );
}
