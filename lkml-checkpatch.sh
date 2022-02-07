#!/bin/bash

set -e

LANG=C

fixed_checkpatch_opts="--show-types --summary-file"
opt_lkml_path=$(realpath ../lkml/0)
opt_linux_tree_root=$(realpath ../linux)
opt_checkpatch_opts="--no-signoff --verbose --subjective --mailback --codespell"
opt_log_dir=$(realpath ../checkpatch-results/)
opt_start_offset=0
opt_num_messages=-1
opt_num_parallel_jobs=$(nproc)
opt_verbose=0

usage() {
local script=$(basename $0)
cat <<EOF
Runs all patches from the Linux Kernel Mailing List (LKML or lkml) archive
through the scripts/checkpatch.pl utility and produces log files for each
in a given directory in case there were errors or warnings.

The LKMK itself is expected ot be cloned as a git repo. It is divided into
12 epochs atm.

  git clone http://lore.kernel.org/lkml/0 lkml/0 # oldest
  git clone http://lore.kernel.org/lkml/1 lkml/1
  git clone http://lore.kernel.org/lkml/2 lkml/2
  ...
  git clone http://lore.kernel.org/lkml/11 lkml/11 # newest 

You're supposed to specify <PATH_TO>/lkml/<NUM> as the --lkml-path

See also this site for more information on the git mirror of the LKML:
https://lore.kernel.org/lkml/_/text/mirror/

Usage: ${script}
    --lkml-path <LKML_GIT_CLONE_DIR>                      defaults to: ${opt_lkml_path}
    --linux-tree-root <LINUX_ROOT_DIR>                    defaults to: ${opt_linux_tree_root}
    --checkpatch-opts "<FLAGS_FOR_CHECHPATCH.PL>"         defaults to: ${opt_checkpatch_opts}. These flags are always added: ${fixed_checkpatch_opts}
    --log-dir <DIRECTORY_WHERE_TO_STORE_CHECKPATCH_LOGS>  defaults to: ${opt_log_dir}
                                                          (will be created if it doesn't exist)
    --start-offset <MESSAGE_OFFSET_IN_LKML>               defaults to: ${opt_start_offset}
    --num-messages <NUM_MESSAGES>                         defaults to: git -C <LKML_GIT_CLONE_DIR> rev-list HEAD --count
    --num-parallel-jobs <NUM_JOBS>                        defaults to: ${opt_num_parallel_jobs}
    --verbose                                             will turn on what commands are being run in each step (not enabled by default)
    --help | -help | -h                                   display this help text
EOF
}

while [ $# -gt 0 ]; do
    case $1 in
        --lkml-path )
            shift
            opt_lkml_path=$1
            ;;
        --linux-tree-root )
            shift
            opt_linux_tree_root=$(realpath $1)
            ;;
        --checkpatch-opts )
            shift
            opt_checkpatch_opts="$1"
            ;;
        --log-dir )
            shift
            opt_log_dir=$1
            ;;
        --log-dir )
            shift
            opt_log_dir=$1
            ;;
        --start-offset )
            shift
            opt_start_offset=$1
            ;;
        --num-messages )
            shift
            opt_num_messages=$1
            ;;
        --num-parallel-jobs )
            shift
            opt_num_parallel_jobs=$1
            ;;
        --verbose )
            opt_verbose=1
            ;;
        -h | -help | --help )
            usage
            exit 0
            ;;
        * )
            echo "unknown option: $1"
            usage
            exit 1
            ;;
    esac
    shift
done

if [ "$opt_num_messages" == "-1" ]; then
    opt_num_messages=$(git -C $opt_lkml_path rev-list HEAD --count)
fi

run_checkpath_against_lkml() {
    cat <<EOF
Start-Offset: $opt_start_offset
# Messages  : $opt_num_messages
EOF

    # Checkpatch runs on a temporary patch file and we want the name to reflect
    # where it originated from. That's why the patch includes the opt_lkml_path.
    tempdir=$(mktemp -d -p .)
    tempdir=$tempdir/$opt_lkml_path
    mkdir -p $tempdir
    # tmplogfile=$tempdir/checkpatch.log
    
    # final destination for log files
    logdir=$opt_log_dir/$opt_lkml_path
    mkdir -p $logdir
    
    end_offset=$((opt_start_offset + opt_num_messages - 1))

    # run parallel jobs and stop when the first job failed. Running ones will not be killed
    seq $opt_start_offset $end_offset | parallel -j $opt_num_parallel_jobs --halt soon,fail=1 --bar "
        if [ "$opt_verbose" == "1" ]; then
            set -x;
        fi
        offset={};
        offset_str=\$(printf \"%010d\" \$offset);
        #echo \"======= start-offset: $opt_start_offset end-offset: $end_offset offset:\$offset_str bashpid: \$BASHPID  job-slot: {%}=======\";
        sha1=\$(git -C $(realpath $opt_lkml_path) log --format=\"%H\" -n1 HEAD~$offset);
        patchfile=$tempdir/patch.offset.\$offset_str.commit.\$sha1;
        git -C $opt_lkml_path show HEAD~{}:m > \$patchfile;
	if [ \"\$?\" != \"0\" ]; then
            kill -SIGHUP \$PARALLEL_PID; # stops parallel but does not kill running jobs
        else
            tmplogfile=$tempdir/checkpatch.log.\$BASHPID;
            $opt_linux_tree_root/scripts/checkpatch.pl --root=$opt_linux_tree_root $fixed_checkpatch_opts $opt_checkpatch_opts \$patchfile 2>&1 > \$tmplogfile;
            if [ -s \$tmplogfile ]; then
                mv \$tmplogfile $logdir/\$offset_str.\$sha1;
            fi;
	fi;
        rm -f \$patchfile;
        rm -f \$tmplogfile;"
}

run_checkpath_against_lkml

exit 0
