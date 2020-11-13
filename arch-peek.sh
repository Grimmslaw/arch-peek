#!/bin/bash
#
# Author: Wes Rickey
#
# Peek into an archive file (.jar, .war, etc.) using a temporarily-created location for it to be inflated.

# script vars ==
programname="$0"
RETURNDIR="$(pwd)"

# flags ==
INTERACTIVE=1
VERBOSE=0

######################################################################
# Provide usage information for this script and halt execution.
# Globals:
#   none
# Arguments:
#   PROGRAMNAME:    the name of this script
######################################################################
usage () {
    PROGRAMNAME=$1
    echo ""
    echo "Usage: $PROGRAMNAME [-iv] [-d dirname] archive_file"
    echo "Peek into an archive file (any .*ar that is a legal argument to the 'jar' command)"
    echo ""
    echo "  -h      display this help text and quit"
    echo "  -n      disable interactive mode (i.e. the temporary directory will be create, the file will be inflated, your directory will be changed to that temporary directory, and the program will exit)"
    echo "  -v      verbose mode: echo commands as they are called [not respected during interactive loop]"
    echo "  -d  dirname     specify a directory relative to which '/tmp/temp-explode' should be updated or created"
    echo ""
	
	exit 1
}

ROOTCONTEXT=""

while getopts ":hnvd:" opt; do
    case $opt in
        n ) INTERACTIVE=0
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

######################################################################
# Create the temporary environment in which the chosen archive will
#   be inflated, change to the target directory, and then inflate the
#   archive there.
# Globals:
#   none
# Arguments:
#   ARTIFACT:   the path to the archive to be inflated
#   PEEKROOT:   the root directory to inflate the archive in
######################################################################
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

######################################################################
# Either change to a target directory or output the contents of a
#   target file, depending on which is given as an argument.
# Globals:
#   none
# Arguments:
#   FILEORDIR:  a path to either a file or a directory
######################################################################
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
#   CONFIRMTEXT:    the text to ask the user to confirm (e.g. "Are you
#                   sure {something}?"
######################################################################
userconfirm () {
    CONFIRMTEXT=$1
    echo -n "$CONFIRMTEXT (y/N) "
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
			userconfirm "This will delete this temporary folder. Are you sure?"
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

