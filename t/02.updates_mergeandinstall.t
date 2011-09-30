#!perl

use Test::More;
use strict;
use FindBin qw($Bin);
use English qw( -no_match_vars );

require "$Bin/helper.pl";

my $file_slurp_available = load_mod('File::Slurp qw(read_file)');

my $profile_filename = ( lc($OSNAME) eq 'darwin' ) ? '.profile' : '.bashrc';

subtest 'updates and mergeandinstall' => sub {
    my ( $home, $repo, $origin ) = minimum_home('host1');
    my ( $home2, $repo2 ) = minimum_home( 'host2', $origin );

    add_file_and_push($repo);

    my $output;

    $output = `HOME=$home2 perl $repo2/bin/dfm updates 2> /dev/null`;
    like( $output, qr/adding \.testfile/, 'message in output' );
    ok( !-e "$repo2/.testfile", 'updated file is not there' );

    # remove the origin repo, to make sure that --no-fetch
    # still works (because the updates are already local,
    # --no-fetch doesn't refetch)
    `rm -rf $origin`;
    $output
        = `HOME=$home2 perl $repo2/bin/dfm updates --no-fetch 2> /dev/null`;
    like( $output, qr/adding \.testfile/, 'message in output' );
    ok( !-e "$repo2/.testfile", 'updated file is not there' );

    $output = `HOME=$home2 perl $repo2/bin/dfm mi 2> /dev/null`;
    like( $output, qr/\.testfile/, 'message in output' );
    ok( -e "$repo2/.testfile", 'updated file is there' );
    ok( -l "$home2/.testfile", 'updated file is installed' );
};

done_testing;

sub add_file_and_push {
    my $repo     = shift;
    my $filename = shift || '.testfile';
    my $contents = shift || 'contents';

    chdir($repo);
    `echo '$contents' > $filename`;
    `git add $filename`;
    `git commit -m 'adding $filename'`;
    `git push origin master 2> /dev/null`;
    chdir($Bin);
}
