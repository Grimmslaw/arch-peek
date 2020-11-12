#!/bin/bash
#
# Author: Wes Rickey

# script vars ==
programname="$0"
RETURNDIR="$(pwd)"

# flags ==
INTERACTIVE=0
VERBOSE=0
ROOTISRELATIVE=0

usage () {
	echo ""
	echo "Usage: $programname [-iv] [-d dirname] archive_file"
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

# parse args
while getopts ":hivd:" opt; do
	case $opt in
		i ) INTERACTIVE=1
			;;
        v ) VERBOSE=1
            ;;
        d ) ROOTCONTEXT="$OPTARG"
            ;;
		\?)	echo "Invalid option: -$OPTARG. Aborting." 1>&2
			exit 1
			;;
        : ) echo "Invalid option: -$OPTARG requires an argument. Aborting." 1>&2
            exit 1
            ;;
        h | * ) usage
			;;
	esac
done

maybeprint () {
    if [ $VERBOSE -eq 0 ] || [ $# -eq 0 ]; then
        return 0
    elif [ $# -gt 2 ]; then
        echo "Function 'maybeprint' must have no more than 2 arguments"
        return 1
    fi

    if [ $# -eq 1 ]; then
        echo "  (>) $1"
    elif [ $# -eq 2 ]; then
        echo "  (>) [log] $1: $2"
    fi
}

# dependent script vars ==
FILEPATH="${@:$OPTIND:1}"
FILENAME="$(basename $FILEPATH)"
PROJECTNAME="${FILENAME%.*}"
EXPLODEROOT="/tmp/temp-explode"
TEMPROOT="${ROOTCONTEXT}${EXPLODEROOT}/${PROJECTNAME}"

userconfirm () {
	# returns 0 for true and 1 for false, in that a 0 return code represents a non-error return
	echo -n "Are you sure? (y/N) "
	read res
	RESPONSE="$(echo $res | awk '{print tolower($0)}')"
	if [ $RESPONSE = "yes" ] || [ $RESPONSE = "y" ]; then
		return 0
	else
		return 1
	fi
}

cleanup () {
    maybeprint "cd $RETURNDIR"
	cd $RETURNDIR
    maybeprint "rm -rf $TEMPROOT"
	rm -rf $TEMPROOT
}

# clear if directory exists; or create if not
if [ -d $TEMPROOT ]
then
    maybeprint "rm -rf $TEMPROOT/*"
	rm -rf "$TEMPROOT""/*"
else
    maybeprint "mkdir -p $TEMPROOT"
	mkdir -p $TEMPROOT
fi

maybeprint "cp $FILEPATH $TEMPROOT"
cp $FILEPATH $TEMPROOT
maybeprint "cd $TEMPROOT"
cd $TEMPROOT
maybeprint "mkdir exploded"
mkdir exploded
maybeprint "cd exploded"
cd exploded
maybeprint "jar xvf $FILEPATH"
# suppressing output of .*ar inflation
jar xvf $FILEPATH > /dev/null

if [ $INTERACTIVE -eq 1 ]
then
    while true
	do
        echo ""
	    echo "Choose a directory to change to that directory or a file to 'cat' that file."
	    echo "    (Press and enter 'q' to exit this peek and destroy the temporary directory.)"

		echo ""
        echo "(cwd) $(pwd)"
        echo ""
        echo "$(ls -al)"
		echo ""
		read -p "|> " -r SELECTION
        echo ""
        echo "-------------------------------"
		if [ $SELECTION = "q" ]
		then
			userconfirm
            CONFIRM=$?
			if [ $CONFIRM -eq 0 ]
			then
				cleanup
                echo ""
				break
			fi
		fi
		
		maybeprint "SELECTION" $SELECTION
        echo ""
        if [ -d $SELECTION ]; then
            cd $SELECTION
        elif [ -f $SELECTION ]; then
            echo "\"\"\" ($SELECTION)"
            echo ""
            cat $SELECTION
            echo ""
            echo "\"\"\""
        else
            echo "Invalid selection. Try again."
        fi
	done
fi

