#!/bin/bash

set -e

fixed_checkpatch_opts="--show-types --summary-file"
opt_lkml_path=$(realpath ~/dev/lkml/0)
opt_linux_tree_root=$(realpath ~/dev/linux)
opt_checkpatch_opts="--no-signoff --verbose --subjective --mailback --codespell"
opt_log_dir=$(realpath ~/checkpatch-logs/)
opt_start_offset=0
opt_num_messages=-1

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
#Messages:    $opt_num_messages
EOF

    # Checkpatch runs on a temporary patch file and we want the name to reflect
    # where it originated from. That's why the patch includes the opt_lkml_path.
    tempdir=$(mktemp -d)
    tempdir=$tempdir/$opt_lkml_path
    mkdir -pv $tempdir
    tmplogfile=$tempdir/checkpatch.log
    
    # final destination for log files
    logdir=$opt_log_dir/$opt_lkml_path
    mkdir -pv $logdir
    
    end_offset=$((opt_start_offset + opt_num_messages - 1))
    for offset in $(seq $opt_start_offset $end_offset); do
        echo "======= start-offset: $opt_start_offset offset:$offset end-offset: $end_offset ======="

        # Get the n-th message from the mailing list (aka the patch message) and save it
        # as a patchfile to be checked by checkpatch.pl
        sha1=$(git -C $(realpath $opt_lkml_path) log --format="%H" -n1 HEAD~$offset)
        patchfile=$tempdir/patch.offset.$(printf "%05d" $offset).commit.$sha1
        git -C $opt_lkml_path show HEAD~$offset:m > $patchfile
        
        # Run checkpatch on the patchfile and if it found something,
        # save the result in a properly named file.
        rm -f $tmplogfile
        $opt_linux_tree_root/scripts/checkpatch.pl --root=$opt_linux_tree_root $fixed_checkpatch_opts $opt_checkpatch_opts $patchfile 2>&1 | tee $tmplogfile
        if [ -s $tmplogfile ]; then
            mv -v $tmplogfile $logdir/$(printf "%05d" $offset).$sha1;
        fi
    done
}

run_checkpath_against_lkml

exit 0
