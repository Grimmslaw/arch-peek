#!/bin/bash
#
# Author: Wes Rickey
#
# Peek into an archive file (.jar, .war, etc.) using a temporarily-created location for it to be inflated.

# script vars ==
programname="$0"
RETURNDIR="$(pwd)"

# flags ==
INTERACTIVE=0
VERBOSE=0
ROOTISRELATIVE=0

usage () {
    PROGRAMNAME=$1
    echo ""
    echo "Usage: $PROGRAMNAME [-iv] [-d dirname] archive_file"
    echo "Peek into an archive file (any .*ar that is a legal argument to the 'jar' command)"
    echo ""
    echo "  -h      display this help text and quit"
    echo "  -i      run this program in interactive mode and destroy the temporary directory on exit"
    echo "  -v      verbose mode: echo commands as they are called [not respected during interactive loop]"
    echo "  -d  dirname     specify a directory relative to which '/tmp/temp-explode' should be updated or created"
    echo ""
	
	exit 1
}

ROOTCONTEXT=""

while getopts ":hivd:" opt; do
    case $opt in
        i ) INTERACTIVE=1
            ;;
        v ) VERBOSE=1
            ;;
        d ) ROOTCONTEXT="$OPTARG"
            ;;
        \?) echo "Invalid option: -$OPTARG. Aborting." 1>&2
            exit 1
            ;;
        : ) echo "Invalid option: -$OPTARG requires an argument. Aborting." 1>&2
            exit 1
            ;;
        h | * ) usage $programname
            ;;
    esac
done

######################################################################
# Print the given text to stdout iff verbose mode (VERBOSE, -v) is on.
# Globals:
#   VERBOSE
# Arguments:
#   FIRSTSTR (opt.)
#   SECONDSTR (opt.)
#
# If no arguments are given, this simply exits with a success code.
# If one argument is given, it is printed as given iff verbose mode
#   is on.
# If two arguments are given, the first represents a variable name,
#   and the second represents its value. They are printed as
#   "  (>) name: value".
######################################################################
maybeprint () {
    FIRSTSTR=$1
    SECONDSTR=$2

    if [ $VERBOSE -eq 0 ] || [ $# -eq 0 ]; then
        return 0
    elif [ $# -gt 2 ]; then
        echo "Function 'maybeprint' can have no more than 2 arguments"
        return 1
    fi

    if [ $# -eq 1 ]; then
        echo "  (>) $FIRSTSTR"
    elif [ $# -eq 2 ]; then
        echo "  (>) [log] $FIRSTSTR: $SECONDSTR"
    fi
}

create_env () {
    ARTIFACT=$1
    PEEKROOT=$2
    maybeprint "cp $ARTIFACT $PEEKROOT"
    cp $ARTIFACT $PEEKROOT
    
    maybeprint "cd $PEEKROOT"
    cd $PEEKROOT
    
    maybeprint "mkdir exploded; cd exploded"
    mkdir exploded; cd exploded
    
    maybeprint "jar xvf $ARTIFACT"
    # inflate but suppress output
    jar xvf $ARTIFACT > /dev/null 2>&1
}

cd_or_cat () {
    FILEORDIR=$1

    maybeprint "SELECTION" $FILEORDIR
    echo ""
    if [ -d $FILEORDIR ]; then
        cd $FILEORDIR
    elif [ -f $FILEORDIR ]; then
        echo "\"\"\" ($FILEORDIR)"
        echo ""
        cat "$FILEORDIR"
        echo ""
        echo "\"\"\""
    else
        echo "Invalid selection. Try again."
    fi

    echo ""
}

######################################################################
# Get confirmation from a user on the last action taken. A returned
#   success code represents a "Yes" response, while a filure code
#   represents a "No" response.
# Globals:
#   none
# Arguments:
#   none
######################################################################
userconfirm () {
	echo -n "Are you sure? (y/N) "
	read res
	RESPONSE="$(echo $res | awk '{print tolower($0)}')"
	if [ $RESPONSE = "yes" ] || [ $RESPONSE = "y" ]; then
		return 0
	else
		return 1
	fi
}

######################################################################
# Clean up everything created during this script's execution.
# Globals:
#   RETURNDIR
#   TEMPROOT
# Arguments:
#   none
######################################################################
cleanup () {
    maybeprint "cd $RETURNDIR"
	cd $RETURNDIR
    maybeprint "rm -rf $TEMPROOT"
	rm -rf $TEMPROOT
}

######################################################################
# Prepare the temporary environment that the archive will be inflated
#   into.
# Globals:
#   none
# Arguments:
#   peekroot:   the directory in which the environment will be
#               temporarily set up
######################################################################
prepare_env () {
    PEEKROOT=$1
    if [ -d $PEEKROOT ]; then
        maybeprint "rm -rf $PEEKROOT/*"
        rm -rf "$PEEKROOT/*"
    else
        maybeprint "mkdir -p $PEEKROOT"
        mkdir -p $PEEKROOT
    fi
}

######################################################################
# Continuously ask the user to choose a file or directory from current
#   directory, then read selection is a file or change directory if
#   selection is a directory. Loop ends when user enters "q" and
#   confirms they wish for the temporary directory to be removed.
# Globals:
#   none
# Arguments:
#   none
######################################################################
interact () {
    echo ""
    while true; do
        echo "Choose a directory to change to that directory or a file to 'cat' that file."
        echo "  (Press and enter 'q' to exit this peek and destroy the temporary directory.)"
        
        echo ""
        echo "(cwd) $(pwd)"
        echo ""
        echo "$(ls -al)"
		echo ""
		read -p "|> " -r SELECTION
        echo ""
        echo "-------------------------------"
        
        if [ $SELECTION = "q" ]; then
			userconfirm
            CONFIRM=$?
			if [ $CONFIRM -eq 0 ]; then
				cleanup
                echo ""
				break
			fi
		fi

        cd_or_cat $SELECTION
    done
}

#############################
# ==== Main Script Body === #
#############################

# dependent script vars ==
FILEPATH="${@:$OPTIND:1}"
FILENAME="$(basename $FILEPATH)"
PROJECTNAME="${FILENAME%.*}"
EXPLODEROOT="/tmp/temp-explode"
TEMPROOT="${ROOTCONTEXT}${EXPLODEROOT}/${PROJECTNAME}"

prepare_env $TEMPROOT

create_env $FILEPATH $TEMPROOT

if [ $INTERACTIVE -eq 1 ]; then
    interact
fi
