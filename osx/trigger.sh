#!/bin/bash
# Trigger: Run a command when a change occurs on the filesystem
# Usage:
#       trigger [<paths>] -- <command>

# Parse command line.
WATCH_DIRS=""
TRIGGER_CMD=""

# Loop through options until we reach "--", or the end
while [ "$1" != "--" -a $# -ne 0 ]; do
        WATCH_DIRS="$WATCH_DIRS $1"
        shift
done

# shift out the "--" option. The rest is the commend to run
shift
TRIGGER_CMD=$*

# Temporary directory to put a named pipe in
TEMP_DIR=`mktemp -d -t trigger`

# Named pipe to read/write filesystem events
FSEVENT_PIPE=$TEMP_DIR/fsevent
mkfifo $FSEVENT_PIPE

# Write file system events into the pipe
FSEVENT_WATCH_CMD="$(dirname $0)/bin/fsevent_watch -f classic"
$FSEVENT_WATCH_CMD $WATCH_DIRS 1> $FSEVENT_PIPE 2> /dev/null &

# Register a signal handler for if (when) we are told to exit
cleanup()
# Remove temporary files
{
        echo "CTRLC"
        if [ -p "$FSEVENT_PIPE" ]
        then
                rm "$FSEVENT_PIPE"
        fi

        if [ -d "$TEMP_DIR" ]
        then
                rmdir "$TEMP_DIR"
        fi
        exit $?
}
trap cleanup SIGINT

# Read from the pipe, and run the trigger command for every line read
cat $FSEVENT_PIPE | while read ; do
        $TRIGGER_CMD
done

# If we manage to get here without an interupt, then cleanup
cleanup
