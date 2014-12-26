#!/usr/bin/perl

use strict;
use warnings;
use English qw( -no_match_vars );    # Avoids regex performance penalty
use Data::Dumper;
use FindBin qw($RealBin $RealScript);
use Getopt::Long;
use Cwd qw(realpath getcwd);
use File::Spec;
use File::Copy;
use File::Basename;
use Pod::Usage;

our $VERSION = 'v0.7.4';

my %opts;
my $shellrc_filename;
my $shellrc_load_filename;
my $repo_dir;
my $home;

my $command_aliases = {
    'mi'  => 'mergeandinstall',
    'umi' => 'updatemergeandinstall',
    'un'  => 'uninstall',
    'im'  => 'import',
    'in'  => 'install'
};

my $commands = {
    'install' => sub {
        DEBUG("Running in [$RealBin] and installing in [$home]");

        # install files
        install( $home, $repo_dir );
    },
    'updates' => sub {
        my $argv = shift;

        GetOptionsFromArray( $argv, \%opts, 'no-fetch' );

        fetch_updates( \%opts );
    },
    'mergeandinstall' => sub {
        my $argv = shift;

        GetOptionsFromArray( $argv, \%opts, 'merge', 'rebase' );

        merge_and_install( \%opts );
    },
    'updatemergeandinstall' => sub {
        my $argv = shift;

        GetOptionsFromArray( $argv, \%opts, 'merge', 'no-fetch' );

        fetch_updates( \%opts );
        merge_and_install( \%opts );
    },
    'uninstall' => sub {
        my $argv = shift;

        # uninstall files
        uninstall($home, $repo_dir);
    },
    'import' => sub {
        my $argv = shift;

        GetOptionsFromArray( $argv, \%opts, 'message=s', 'no-commit|n' );

        # import files
        import_files( _abs_repo_path( $home, $repo_dir ), $home, $argv );
    },
    'help' => sub {
        my $argv = shift;

        my $command = shift @$argv;

        if ($command) {
            $command = $command_aliases->{$command} || $command;

            my %options = (
                -verbose    => 99,
                -exitstatus => 0,
                -sections   => uc($command),
            );

            # if run as part of test, add option to point
            # to real script source
            if ( $RealScript eq '04.misc.t' ) {
                $options{'-input'} = '../dfm';
            }

            pod2usage(%options);
        }
        else {
            pod2usage(2);
        }
    },
};

run_dfm( $RealBin, @ARGV ) unless defined caller;

sub run_dfm {
    my ( $realbin, @argv ) = @_;

    # set options to nothing so that running multiple times in tests
    # does not reuse options
    %opts = ();
    $shellrc_filename = undef;
    $shellrc_load_filename = undef;
    $repo_dir = undef;
    $home = undef;

    my $command;

    if ( scalar(@argv) == 0 || $argv[0] =~ /^-/ ) {

        # check to make sure there's not a dfm subcommand later in the arg list
        if ( grep { exists $commands->{$_} } @argv ) {
            ERROR("The command should be first.");
            exit(-2);
        }
        $command = 'help';
    }
    else {
        $command = $argv[0];
    }

    $command = $command_aliases->{$command} || $command;

    if ( exists $commands->{$command} ) {

        # parse global options first
        Getopt::Long::Configure('pass_through');
        GetOptionsFromArray( \@argv, \%opts, 'verbose', 'quiet', 'dry-run', 'help', 'version' );
        Getopt::Long::Configure('no_pass_through');
    }

    $home = realpath( $ENV{HOME} );
    if ( !$home ) {
        ERROR("unable to determine 'realpath' for $ENV{HOME}");
        exit(-2);
    }

    if ( $ENV{'DFM_REPO'} ) {
        $repo_dir = $ENV{'DFM_REPO'};
        $repo_dir =~ s/$home\///;
    }
    elsif ( -e "$realbin/t/02.updates_mergeandinstall.t" ) {

        # dfm is being invoked from its own repo, not a dotfiles repo; try and
        # figure out what repo in the users's homedir is the dotfiles repo
        #
        # TODO: alternate strategy: see if there are files in $home that are
        # already symlinked and use those as a guide
        foreach my $potential_dotfiles_repo (qw(.dotfiles dotfiles)) {
            if (   -d "$home/$potential_dotfiles_repo"
                && -d "$home/$potential_dotfiles_repo/.git" )
            {
                $repo_dir = "$home/$potential_dotfiles_repo";
                $repo_dir =~ s/$home\///;
            }
        }

        if ( !$repo_dir ) {
            ERROR("unable to discover dotfiles repo and dfm is running from its own repo");
            exit(-2);
        }
    }
    else {
        $repo_dir = $realbin;
        $repo_dir =~ s/$home\///;
        $repo_dir =~ s/\/bin//;
    }

    DEBUG("Repo dir: $repo_dir");

    # extract the shell name from env
    my $shell = basename( $ENV{SHELL} );
    $shellrc_filename = '.' . $shell . 'rc';

    DEBUG("Shell: $shell, Shell RC filename: $shellrc_filename");

    # shellrc in MacOS is ~/.profile
    if ( lc($OSNAME) eq 'darwin' and $shell eq 'bash' ) {
        $shellrc_filename = '.profile';
    }

    if ( exists $commands->{$command} ) {
        if ( $opts{'help'} ) {
            $commands->{'help'}->( [$command] );
        }
        elsif ( $opts{'version'} ) {
            show_version();
        }
        else {
            shift(@argv);    # remove the command from the array
            $commands->{$command}->( \@argv );
        }
    }
    else {

        # assume it's a git command and call accordingly
        _run_git(@argv);
    }
}

sub my_symlink {
    my $target = shift;
    my $link   = shift;

    if ($^O eq "cygwin")
    {
        my $flags = "";
        if (-d $target) { $flags = "/D" };

        $target = `cygpath -w $target`;
        $link   = `cygpath -w $link`;

        chomp $target;
        chomp $link;

        my $command = "cmd /c mklink $flags \"$link\" \"$target\"";
        system($command);
    }
    else
    {
        symlink($target,$link);
    }
}

sub get_changes {
    my $what = shift;

    return `git log --pretty='format:%h: %s' $what`;
}

sub get_current_branch {
    my $current_branch = `git symbolic-ref HEAD`;
    chomp $current_branch;

    # convert 'refs/heads/personal' to 'personal'
    $current_branch =~ s/^.+\///g;

    DEBUG("current branch: $current_branch");

    return $current_branch;
}

sub check_remote_branch {
    my $branch        = shift;
    my $branch_remote = `git config branch.$branch.remote`;
    chomp $branch_remote;

    DEBUG("remote for branch $branch: $branch_remote");

    if ( $branch_remote eq "" ) {
        WARN("no remote found for branch $branch");
        exit(-1);
    }
}

# a few log4perl-alikes
sub ERROR {
    print "ERROR: @_\n";
}

sub WARN {
    print "WARN: @_\n";
}

sub INFO {
    print "INFO: @_\n" if !$opts{quiet};
}

sub DEBUG {
    print "DEBUG: @_\n" if $opts{verbose};
}

sub fetch_updates {
    my $opts = shift;

    chdir( _abs_repo_path( $home, $repo_dir ) );

    if ( !$opts->{'no-fetch'} ) {
        DEBUG('fetching changes');
        system("git fetch") if !$opts->{'dry-run'};
    }

    my $current_branch = get_current_branch();
    check_remote_branch($current_branch);

    print get_changes("$current_branch..$current_branch\@{u}"), "\n";
}

sub merge_and_install {
    my $opts = shift;

    chdir( _abs_repo_path( $home, $repo_dir ) );

    my $current_branch = get_current_branch();
    check_remote_branch($current_branch);

    my $sync_command = $opts->{'rebase'} ? 'rebase' : 'merge';

    if ( get_changes("$current_branch..$current_branch\@{u}") ) {

        # check for local commits
        if ( my $local_changes = get_changes("$current_branch\@{u}..$current_branch") ) {

            # if a decision wasn't made about how to deal with local commits
            if ( !$opts->{'merge'} && !$opts->{'rebase'} ) {
                WARN("local changes detected, run with either --merge or --rebase");
                print $local_changes, "\n";
                exit;
            }
        }

        INFO("using $sync_command to bring in changes");
        system("git $sync_command $current_branch\@{u}")
            if !$opts->{'dry-run'};

        INFO("re-installing dotfiles");
        install( $home, $repo_dir ) if !$opts->{'dry-run'};
    }
    else {
        INFO("no changes to merge");
    }
}

sub install {
    my ( $home, $repo_dir ) = @_;

    INFO( "Installing dotfiles..." . ( $opts{'dry-run'} ? ' (dry run)' : '' ) );

    DEBUG("Running in [$RealBin] and installing in [$home]");

    install_files( _abs_repo_path( $home, $repo_dir ), $home );

    $shellrc_load_filename = '';

    # link in the shell loader
    if ( -e _abs_repo_path( $home, $repo_dir ) . "/.shellrc.load" ) {
        $shellrc_load_filename = '.shellrc.load';
    }
    elsif ( -e _abs_repo_path( $home, $repo_dir ) . "/.bashrc.load" ) {
        $shellrc_load_filename = '.bashrc.load';
    }

    if ($shellrc_load_filename) {
        configure_shell_loader();
    }
}

sub uninstall {
    my ( $home, $repo_dir ) = @_;

    INFO( "Uninstalling dotfiles..." . ( $opts{'dry-run'} ? ' (dry run)' : '' ) );

    DEBUG("Running in [$RealBin] and installing in [$home]");

    # uninstall files
    uninstall_files( _abs_repo_path( $home, $repo_dir ), $home );

    # link in the shell loader
    if ( -e _abs_repo_path( $home, $repo_dir ) . "/.shellrc.load" ) {
        $shellrc_load_filename = '.shellrc.load';
    }
    elsif ( -e _abs_repo_path( $home, $repo_dir ) . "/.bashrc.load" ) {
        $shellrc_load_filename = '.bashrc.load';
    }

    if ($shellrc_load_filename) {
        unconfigure_shell_loader();
    }
}

# function to install files
# possible options:
#   install_only: list of files to install, as opposed to all of them
sub install_files {
    my ( $source_dir, $target_dir, $options ) = @_;

    my $install_only;

    if ( $options->{install_only}
        && scalar @{ $options->{install_only} } > 0 )
    {
        $install_only = $options->{install_only};
    }

    DEBUG("Installing from $source_dir into $target_dir");

    my $symlink_base = _calculate_symlink_base( $source_dir, $target_dir );

    my $backup_dir = $target_dir . '/.backup';
    DEBUG("Backup dir: $backup_dir");

    my $cwd_before_install = getcwd();
    chdir($target_dir);

    my $dfm_install = _load_dfminstall("$source_dir/.dfminstall");

    if ( !-e $backup_dir ) {
        DEBUG("Creating $backup_dir");
        mkdir($backup_dir) if !$opts{'dry-run'};
    }

    my $dirh;
    opendir $dirh, $source_dir;
    foreach my $direntry ( readdir($dirh) ) {

        if ($install_only) {
            next unless grep { $_ eq $direntry } @$install_only;
        }

        # skip vim swap files
        next if $direntry =~ /^\..*\.sw.$/;

        # skip emacs temporary and backup files
        next if $direntry =~ /^\.#.*$/;
        next if $direntry =~ /^.*~$/;

        # skip any other files
        next if $dfm_install->{skip_files}->{$direntry};

        DEBUG(" Working on $direntry");

        if ( !-l $direntry ) {
            if ( -e $direntry ) {
                INFO("  Backing up $direntry.");
                system("mv '$direntry' '$backup_dir/$direntry'")
                    if !$opts{'dry-run'};
            }
            INFO("  Symlinking $direntry ($symlink_base/$direntry).");
            my_symlink( "$symlink_base/$direntry", "$direntry" )
                if !$opts{'dry-run'};
        }
    }

    cleanup_dangling_symlinks( $source_dir, $target_dir, $dfm_install->{skip_files} );

    foreach my $recurse ( @{ $dfm_install->{recurse_files} } ) {
        if ( -d "$source_dir/$recurse" ) {
            DEBUG("recursing into $source_dir/$recurse");
            if ( -l "$target_dir/$recurse" ) {
                DEBUG("removing symlink $target_dir/$recurse");
                unlink("$target_dir/$recurse");
            }
            if ( !-d "$target_dir/$recurse" ) {
                DEBUG("making directory $target_dir/$recurse");
                mkdir("$target_dir/$recurse");
            }

            my $recurse_options;
            if ($install_only) {
                $recurse_options = {
                    install_only => [
                        map { s/^$recurse\///; $_ }
                        grep {/^$recurse/} @$install_only
                    ]
                };
            }
            install_files( "$source_dir/$recurse", "$target_dir/$recurse", $recurse_options );
        }
        else {
            WARN("couldn't recurse into $source_dir/$recurse, not a directory");
        }
    }

    foreach my $execute ( @{ $dfm_install->{execute_files} } ) {
        my $cwd = getcwd();

        if ( -x "$source_dir/$execute" ) {
            DEBUG("Executing $source_dir/$execute in $cwd");
            system("'$source_dir/$execute'");
        }
        elsif ( -o "$source_dir/$execute" ) {
            system("chmod +x '$source_dir/$execute'");

            DEBUG("Executing $source_dir/$execute in $cwd");
            system("'$source_dir/$execute'");
        }
    }

    foreach my $chmod_file ( keys %{ $dfm_install->{chmod_files} } ) {
        my $new_perms = $dfm_install->{chmod_files}->{$chmod_file};

        # TODO maybe skip if perms are already ok
        DEBUG("Setting permissions on $chmod_file to $new_perms");
        chmod oct($new_perms), $chmod_file;
    }

    # restore previous working directory
    chdir($cwd_before_install);
}

sub configure_shell_loader {
    chdir($home);

    my $shellrc_contents = _read_shellrc_contents();

    # check if the loader is in
    if ( $shellrc_contents !~ /$shellrc_load_filename/ ) {
        INFO("Appending loader to $shellrc_filename");
        $shellrc_contents .= "\n. \$HOME/$shellrc_load_filename\n";
    }

    # if the new loader filename (.shellrc.load) is used, but the old loader
    # filename (.bashrc.load) is in the shell rc, remove it
    if ( $shellrc_load_filename =~ m/shellrc/ && $shellrc_contents =~ /\.bashrc\.load/ ) {
        $shellrc_contents =~ s{\n. \$HOME/\.bashrc\.load\n}{}gs;
    }

    _write_shellrc_contents($shellrc_contents);
}

sub uninstall_files {
    my ( $source_dir, $target_dir ) = @_;

    DEBUG("Uninstalling from $target_dir");

    my $backup_dir = $target_dir . '/.backup';
    DEBUG("Backup dir: $backup_dir");

    chdir($target_dir);

    my $dfm_install = _load_dfminstall("$source_dir/.dfminstall");

    my $dirh;
    opendir $dirh, $target_dir;
    foreach my $direntry ( readdir($dirh) ) {

        DEBUG(" Working on $direntry");

        if ( -l $direntry ) {
            my $link_target = readlink($direntry);
            DEBUG("$direntry points a $link_target");
            my ( $volume, @elements ) = File::Spec->splitpath($link_target);
            my $element = pop @elements;

            my $target_base
                = realpath( File::Spec->rel2abs( File::Spec->catpath( '', @elements ) ) );

            DEBUG( "target_base '", defined $target_base ? $target_base : '', "' $source_dir" );
            if ( defined $target_base and $target_base eq $source_dir ) {
                INFO("  Removing $direntry ($link_target).");
                unlink($direntry) if !$opts{'dry-run'};
            }

            my $backup_path = File::Spec->catpath( '', '.backup', $element );
            if ( -e $backup_path ) {
                INFO("  Restoring $direntry from backup.");
                rename( $backup_path, $element ) if !$opts{'dry-run'};
            }
        }
    }

    foreach my $execute ( @{ $dfm_install->{execute_uninstall_files} } ) {
        my $cwd = getcwd();

        if ( -x "$source_dir/$execute" ) {
            DEBUG("Executing $source_dir/$execute in $cwd");
            system("'$source_dir/$execute'");
        }
        elsif ( -o "$source_dir/$execute" ) {
            system("chmod +x '$source_dir/$execute'");

            DEBUG("Executing $source_dir/$execute in $cwd");
            system("'$source_dir/$execute'");
        }
    }

    foreach my $recurse ( @{ $dfm_install->{recurse_files} } ) {
        if ( -d "$target_dir/$recurse" ) {
            DEBUG("recursing into $target_dir/$recurse");
            uninstall_files( "$source_dir/$recurse", "$target_dir/$recurse" );
        }
        else {
            WARN("couldn't recurse into $target_dir/$recurse, not a directory");
        }
    }
}

sub relative_to_target {
    my ( $tryfile, $target_dir ) = @_;

    if ( -l $tryfile ) {
        my ( $volume, $dirs, $lfile ) = File::Spec->splitpath($tryfile);
        return File::Spec->abs2rel( File::Spec->catfile( realpath($dirs), $lfile ), $target_dir );
    }
    else {
        return File::Spec->abs2rel( realpath($tryfile), $target_dir );
    }
}

sub import_files {
    my ( $source_dir, $target_dir, $files ) = @_;

    my $symlink_base = _calculate_symlink_base( $source_dir, $target_dir );

    foreach my $file (@$files) {

        if ( $file =~ m{^/} ) {
            $file = relative_to_target( $file, $target_dir );
        }
        else {
            my $tryfile = File::Spec->rel2abs($file);

            if ( -e $tryfile ) {

                #print "FOUND in cwd\n";
                $file = relative_to_target( $tryfile, $target_dir );
            }
            else {
                my $tryfile = File::Spec->rel2abs( $file, $target_dir );

                if ( -e $tryfile ) {

                    #print "FOUND in home\n";
                    $file = relative_to_target( $tryfile, $target_dir );
                }
            }
        }

        if ( $file =~ /^\.\./ ) {
            ERROR("file $file is not in your home directory");
            return;
        }

        # if dfm import $HOME is called
        if ( $file eq '.' ) {
            ERROR("unable to import your home directory itself");
            return;
        }

        if ( !-e "$target_dir/$file" ) {
            ERROR("file $file not found, unable to import");
            return;
        }

        DEBUG("file path, relative to homedir: $file");

        my ( $in_a_subdir, $subdir )
            = _file_in_tracked_or_untracked( $source_dir, $source_dir, $file );
        if ( $in_a_subdir eq 'untracked' ) {
            ERROR(
                "file $file is in a subdirectory that is not tracked, consider using 'dfm import $subdir'."
            );
            return;
        }
        elsif ( $in_a_subdir eq 'tracked' ) {
            ERROR(
                "file $file is in a subdirectory that is already tracked, consider using 'dfm add $subdir'."
            );
            return;
        }
        elsif ( $in_a_subdir eq 'skip' ) {
            ERROR("file $file is skipped.");
            return;
        }

        # detect file that's already tracked, either by being a symlink that
        # points into the repo or in the repo itself
        if ((   -l "$target_dir/$file"
                && ( readlink("$target_dir/$file") =~ /(\.\.\/)*$symlink_base/ )
            )
            || $file =~ /^$symlink_base/
            )
        {
            ERROR("file $file is already tracked.");
            return;
        }

    }

    my $message = $opts{message} || "importing " . join( ', ', @$files );

    foreach my $file (@$files) {
        INFO( "Importing $file from $target_dir into $source_dir"
                . ( $opts{'dry-run'} ? ' (dry run)' : '' ) );

        DEBUG("moving $file into $source_dir");
        if ( !$opts{'dry-run'} ) {
            move( "$target_dir/$file", "$source_dir/$file" );
        }

        if ( !$opts{'dry-run'} ) {
            _run_git( 'add', $file );
        }
    }

    install_files( _abs_repo_path( $home, $repo_dir ), $home, { install_only => [@$files] } );

    INFO( "Committing with message '$message'" . ( $opts{'dry-run'} ? ' (dry run)' : '' ) );
    if ( !$opts{'dry-run'} ) {
        if ( !$opts{'no-commit'} ) {
            _run_git( 'commit', @$files, '-m', $message );
        }
    }
}

sub cleanup_dangling_symlinks {
    my ( $source_dir, $target_dir, $skip_files ) = @_;
    $skip_files ||= {};

    DEBUG(" Cleaning up dangling symlinks in $target_dir");

    my $dirh;
    opendir $dirh, $target_dir;
    foreach my $direntry ( readdir($dirh) ) {

        DEBUG(" Working on $direntry");

        # if symlink is dangling or is now skipped
        if ( -l $direntry && ( !-e $direntry || $skip_files->{$direntry} ) ) {
            my $link_target = readlink($direntry);
            DEBUG("$direntry points at $link_target");
            my ( $volume, @elements ) = File::Spec->splitpath($link_target);
            my $element = pop @elements;

            my $target_base
                = realpath( File::Spec->rel2abs( File::Spec->catpath( '', @elements ) ) );

            DEBUG( "target_base '", defined $target_base ? $target_base : '', "' $source_dir" );
            if ( defined $target_base and $target_base eq $source_dir ) {
                INFO("  Cleaning up dangling symlink $direntry ($link_target).");
                unlink($direntry) if !$opts{'dry-run'};
            }
        }
    }
}

sub unconfigure_shell_loader {
    chdir($home);

    my $shellrc_contents = _read_shellrc_contents();

    # remove shell loader if found
    $shellrc_contents =~ s{\n. \$HOME/$shellrc_load_filename\n}{}gs;

    _write_shellrc_contents($shellrc_contents);
}

sub _write_shellrc_contents {
    my $shellrc_contents = shift;

    if ( !$opts{'dry-run'} ) {
        open( my $shellrc_out, '>', $shellrc_filename );
        print $shellrc_out $shellrc_contents;
        close $shellrc_out;
    }
}

sub _read_shellrc_contents {
    my $shellrc_contents;
    {
        local $INPUT_RECORD_SEPARATOR = undef;
        if ( open( my $shellrc_in, '<', $shellrc_filename ) ) {
            $shellrc_contents = <$shellrc_in>;
            close $shellrc_in;
        }
        else {
            $shellrc_contents = '';
        }
    }
    return $shellrc_contents;
}

sub _run_git {
    my @args = @_;

    my $cwd_before_git = getcwd();

    DEBUG( 'running git ' . join( ' ', @args ) . " in $home/$repo_dir" );
    chdir( _abs_repo_path( $home, $repo_dir ) );
    system( 'git', @args );

    chdir($cwd_before_git);
}

sub _abs_repo_path {
    my ( $home, $repo ) = @_;

    if ( File::Spec->file_name_is_absolute($repo) ) {
        return $repo;
    }
    else {
        return $home . '/' . $repo;
    }
}

# when symlinking from source_dir into target_dir, figure out if there's a
# relative path between the two
sub _calculate_symlink_base {
    my ( $source_dir, $target_dir ) = @_;

    my $symlink_base;

    # if the paths have no first element in common
    if ( ( File::Spec->splitdir($source_dir) )[1] ne ( File::Spec->splitdir($target_dir) )[1] ) {
        $symlink_base = $source_dir;    # use absolute path
    }
    else {

        # otherwise, calculate the relative path between the two directories
        $symlink_base = File::Spec->abs2rel( $source_dir, $target_dir );
    }

    return $symlink_base;
}

sub _file_in_tracked_or_untracked {
    my ( $orig_source_dir, $source_dir, $file ) = @_;

    # strip the repo dir off the front, in case the file is already tracked
    $file =~ s/$repo_dir\///;

    my $cwd_before_inspection = getcwd();
    chdir($source_dir);

    my $dfm_install = _load_dfminstall("$source_dir/.dfminstall");

    # skip vim swap files
    return ('skip') if $file =~ /.*\.sw.$/;

    # skip any other files
    return ('skip') if $dfm_install->{skip_files}->{$file};

    my @dirs = File::Spec->splitdir($file);
    if ( scalar(@dirs) > 1 ) {
        my $recurse_dir = shift(@dirs);
        if ( grep { $recurse_dir eq $_ } @{ $dfm_install->{recurse_files} } ) {
            chdir($cwd_before_inspection);
            return _file_in_tracked_or_untracked(
                $orig_source_dir,
                File::Spec->catfile( $source_dir, $recurse_dir ),
                File::Spec->catfile(@dirs)
            );
        }
        else {
            my $relative_path = File::Spec->abs2rel( $source_dir, $orig_source_dir );

            my $dir_type = -e $recurse_dir ? 'tracked' : 'untracked';

            chdir($cwd_before_inspection);
            return ( $dir_type,
                ( $relative_path eq '.' )
                ? $recurse_dir
                : File::Spec->catfile( $relative_path, $recurse_dir ) );
        }
    }

    chdir($cwd_before_inspection);
    return ('install');
}

sub _load_dfminstall {
    my ($dfminstall_path) = @_;

    my $dfminstall_info = {
        skip_files => {
            '.'           => 1,
            '..'          => 1,
            '.dfminstall' => 1,
            '.gitignore'  => 1,
            '.git'        => 1,
        },
        recurse_files           => [],
        execute_files           => [],
        execute_uninstall_files => [],
        chmod_files             => {},
    };

    if ( -e $dfminstall_path ) {
        open( my $skip_fh, '<', $dfminstall_path );
        foreach my $line (<$skip_fh>) {
            chomp($line);
            if ( length($line) ) {
                my ( $filename, @options ) = split( q{ }, $line );
                DEBUG(".dfminstall file $filename has @options");
                if ( !defined $options[0] ) {
                    WARN(
                        "using implied recursion in .dfminstall is deprecated, change '$filename' to '$filename recurse' in $dfminstall_path."
                    );
                    push( @{ $dfminstall_info->{recurse_files} }, $filename );
                    $dfminstall_info->{skip_files}->{$filename} = 1;
                }
                elsif ( $options[0] eq 'skip' ) {
                    $dfminstall_info->{skip_files}->{$filename} = 1;
                }
                elsif ( $options[0] eq 'recurse' ) {
                    push( @{ $dfminstall_info->{recurse_files} }, $filename );
                    $dfminstall_info->{skip_files}->{$filename} = 1;
                }
                elsif ( $options[0] eq 'exec' ) {
                    push( @{ $dfminstall_info->{execute_files} }, $filename );
                }
                elsif ( $options[0] eq 'exec-uninstall' ) {
                    push( @{ $dfminstall_info->{execute_uninstall_files} }, $filename );
                }
                elsif ( $options[0] eq 'chmod' ) {
                    if ( !$options[1] ) {
                        ERROR("chmod option requires a mode (e.g. 0600) in $dfminstall_path");
                        exit 1;
                    }
                    if ( $options[1] !~ /^[0-7]{4}$/ ) {
                        ERROR(
                            "bad mode '$options[1]' (should be 4 digit octal, like 0600) in $dfminstall_path"
                        );
                        exit 1;
                    }
                    $dfminstall_info->{chmod_files}->{$filename}
                        = $options[1];
                }
            }
        }
        close($skip_fh);
        $dfminstall_info->{skip_files}->{skip} = 1;

        DEBUG("Skipped file: $_") for keys %{ $dfminstall_info->{skip_files} };
    }

    return $dfminstall_info;
}

sub show_version {
    print "dfm version $VERSION\n";
}

# work-alike for function from perl 5.8.9 and later
# added for compatibility with CentOS 5, which is stuck on 5.8.8
sub GetOptionsFromArray {
    my ( $argv, $opts, @options ) = @_;

    local @ARGV = @$argv;
    GetOptions( $opts, @options );

    # update the passed argv array
    @$argv = @ARGV;
}

1;

__END__

=head1 NAME

    dfm - A script to manage a dotfiles repository

=head1 SYNOPSIS

usage: dfm <command> [--version] [--dry-run] [--verbose] [--quiet] [<args>]

The commands are:

   install    Install dotfiles
   import     Add a new dotfile to the repo
   uninstall  Uninstall dotfiles
   updates    Fetch updates but don't merge them in
   mi         Merge in updates and install dotfiles again
   umi        Fetch updates, merge in and install

See 'dfm help <command>' for more information on a specific command.

Any git command can be run on the dotfiles repository by using the following
syntax:

   dfm [git subcommand] [git options]

=head1 DESCRIPTION

    Manages installing files from and operating on a repository that contains
    dotfiles.

=head1 COMMON OPTIONS

All the subcommands implemented by dfm have the following options:

  --verbose     Show extra information about what dfm is doing
  --quiet       Show as little info as possible.
  --dry-run     Don't do anything.
  --version     Print version information.

=head1 HELP

All Options:

  dfm help <subcommand>
  dfm <subcommand> --help

Examples:

  dfm install --help
  dfm help install

Description:

This shows the help for a particular subcommand.

=head1 INSTALL

All Options:

  dfm install [--verbose|--quiet] [--dry-run]

Examples:

  dfm install
  dfm install --dry-run

Description:

This installs everything in the repository into the current user's home
directory by making symlinks.  To skip any files, add their names to a file
named '.dfminstall'.  For instance, to skip 'README.md', put this in
.dfminstall:

    README.md skip

To recurse into a directory and install files inside rather than symlinking the
directory itself, just add its name to .dfminstall.  For instance, to make 'dfm
install' symlink files inside of ~/.ssh instead of making ~/.ssh a symlink, put
this in .dfminstall:

    .ssh

=head1 UNINSTALL

All Options:

  dfm uninstall [--verbose|--quiet] [--dry-run]
   - or -
  dfm un [--verbose|--quiet] [--dry-run]

Examples:

  dfm uninstall
  dfm uninstall --dry-run

Description:

This removes all traces of dfm and the dotfiles.  It basically is the reverse
of 'dfm install'.

=head1 IMPORT

All Options:

  dfm import [--verbose|--quiet] [--dry-run] [--no-commit] [--message <message>] file1 [file2 ..]
   - or -
  dfm im [--verbose|--quiet] [--dry-run] [--no-commit] [--message <message>] file1 [file2 ..]

Examples

  dfm import ~/.vimrc
  dfm import .tmux.conf --message 'adding my tmux config'

Description:

This command moves each file specified into the dotfiles repository and
symlinks it into $HOME.  Then a commit is made.

Use '--message' to specify a different commit message.

Use '--no-commit' to add the files, but not commit.

=head1 UPDATES

All Options:

  dfm updates [--verbose|--quiet] [--dry-run] [--no-fetch]

Examples:

  dfm updates
  dfm updates --no-fetch

Description:

This fetches any changes from the upstream remote and then shows a shortlog of
what updates would come in if merged into the current branch.  Use '--no-fetch'
to skip the fetch and just show what's new.

=head1 MERGEANDINSTALL

All Options:

  dfm mergeandinstall [--verbose|--quiet] [--dry-run] [--merge|--rebase]
   - or -
  dfm mi [--verbose|--quiet] [--dry-run] [--merge|--rebase]

Examples:

  dfm mergeandinstall
  dfm mi
  dfm mergeandinstall --rebase

Description:

This merges or rebases the upstream changes in and re-installs dotfiiles.

=head1 UPDATEMERGEANDINSTALL

All Options:

  dfm updatemergeandinstall [--verbose|--quiet] [--dry-run] [--merge|--rebase] [--no-fetch]
   - or -
  dfm umi [--verbose|--quiet] [--dry-run] [--merge|--rebase] [--no-fetch]

Examples:

  dfm updatemergeandinstall
  dfm umi
  dfm updatemergeandinstall --no-fetch

Description:

This combines 'updates' and 'mergeandinstall'.

=head1 dfm [git subcommand] [git options]

This runs any git command as if it was inside the dotfiles repository.  For
instance, this makes it easy to commit changes that are made by running 'dfm
commit'.

=head1 AUTHOR

Nate Jones <nate@endot.org>

=head1 COPYRIGHT

Copyright (c) 2010 L</AUTHOR> as listed above.

=head1 LICENSE

This program is free software distributed under the Artistic License 2.0.

=cut
