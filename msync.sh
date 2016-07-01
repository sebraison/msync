#!/bin/bash
# 
# Aggregate multiple cloud-synchronized storages into a single mount point.
# Try msync.sh help to more informations or go to homepage at :
# https://github.com/sebraison/msync
#
# (c) 2016 Sébastien Raison
#

KV="`uname -r`"
RCLONE=`which rclone`
IWATCH=`which iwatch`
REALPATH=`which realpath`
AUFS=`find /lib/modules/$KV -iname aufs`

if [ -z $RCLONE ]; then
	# trying to find rclone by ourself
	MSYNC_DIR=`dirname $0`
	RCLONE=`find $MSYNC_DIR -name rclone -perm -u+x 2> /dev/null`
fi


function check_root
{
	if [ `id -u` -ne 0 ]; then
		echo "$0 must be run by root to execute properly, aborting."
		exit -1
	fi
}

function check_base
{
	echo -n "Checking for required components : "
	if [ ! -e "$REALPATH" ]; then
		echo "realpath util not found, aborting."
		exit -1
	fi
	if [ ! -x "$RCLONE" ]; then
		echo "rclone binary not found, aborting."
		exit -1
	fi
	if [ ! -x "$IWATCH" ]; then
		echo "iwatch binary not found, aborting."
		exit -1
	fi
	if [ ! -e "$AUFS" ]; then
		echo "aufs module not found, aborting."
		exit -1
	fi
	echo "OK"
}

function check_dir
{
	DIR=$1
	if [ ! -d "$DIR" ]; then
		mkdir -p "$DIR"
	fi
	if [ `ls -1a $DIR|wc -l` -ne 2 ]; then
		echo "$DIR is not empty, aborting."
		exit -3
	fi
}

function do_help
{
	echo "Aggregate multiple cloud-synchronized storages into a single mount point.

Because we massively rely on rclone, you can use any provider it supports.
We also have its limitations, please refer to its documentation.

Syntax :

    msync.sh <command> <argument> <...>

With command :

    help

        Display this help.

    check <install dir>

        Do simple sanity checks. If no install dir specified, check only for
        base requirements (rclone, iwatch, aufs module). If <install dir> is
        specified, check also if installation is ok.

    install <install dir>

        Setup cache directories in <install dir> using rclone confirgured cloud
        storages.

    import <install dir>

        Retrieve cloud data after a fresh (re) install, MUST be run before the
        start command or you will overwrite all saved data on cloud. Note you
        may have to fix permissions because cloud storages does not preserve
        Unix perms (tool is run as root so he will own all imported files).

    start <install dir> <mount point>

        Start the service previously installed in <install dir> and mount the
        aggregated volume on <mount point>.

    stop <install dir> <mount point>

        Stop the service, unmount the <mount point> and remove it.
        
    
Please refer to https://github.com/sebraison/msync for full documentation.
"
}



case "${1:-}" in
    help)
		do_help
		exit 0
	;;
	check)
		check_root
		check_base
		
		DRIVES=`grep -E '^\[.*\]$' /root/.rclone.conf 2> /dev/null|tr -d \[|tr -d \]`
		if [ -z "$DRIVES" ]; then
			echo "rclone has no cloud storage configured, you should start by this."
			exit 0
		else
			echo "Found configured cloud storages  :" $DRIVES
		fi
		if [ -d "$2" ]; then
			echo -n "Checking install ............... : "
			CACHE_DIR=$2
			HAVE_SOME_CACHES=0
			MISSING_SOME_CACHES=0
			for d in $DRIVES; do
				if [ -d "$CACHE_DIR/$d" ]; then
					HAVE_SOME_CACHES=1
				else
					MISSING_SOME_CACHES=1
				fi
			done
			if [ $HAVE_SOME_CACHES -eq 1 ] && [ $MISSING_SOME_CACHES -eq 1 ]; then
				echo "partial installation detected, aborting."
				exit -1
			elif [ $HAVE_SOME_CACHES -eq 1 ]; then
				echo "OK"
			else
				echo "NO"
				exit 0
			fi
			
			echo -n "Checking if running ............ : "
			
			PID_FILES=`ls -1 $CACHE_DIR/.*_*.pid 2> /dev/null`
			if [ -z "$PID_FILES" ]; then
				echo "seems not."
				exit 0
			fi
			HAVE_SOME_PROCS=0
			MISSING_SOME_PROCS=0
			for pid_file in $PID_FILES; do
				pid=`cat $pid_file`
				if [ `ps --pid $pid | wc -l` -eq 2 ]; then
					HAVE_SOME_PROCS=1
				else
					MISSING_SOME_PROCS=1
				fi
			done
			if [ $HAVE_SOME_PROCS -eq 1 ] && [ $MISSING_SOME_PROCS -eq 1 ]; then
				echo "partialy, not good."
				exit -1
			elif [ $HAVE_SOME_PROCS -eq 1 ]; then
				echo "OK"
			else
				echo "NO (but it may be normal)"
				exit 0
			fi				
		fi
		exit 0
	;;
	sync)
		check_root
		CACHE_DIR=$2
		CSID=$3
		if [ -z "$CACHE_DIR" ] || [ -z "$CSID" ]; then
			echo "WARNING : You should not invoke directly this command (see help)."
			exit -2
		fi
		
		# run one at startup
		$RCLONE sync $CACHE_DIR/$CSID/ $CSID:/msync/ >> $CACHE_DIR/msync.log 2>&1
		LASTEV=0
		while true; do
			if [ -e $CACHE_DIR/.msync_$CSID.last ]; then
				NEWEV=`cat $CACHE_DIR/.msync_$CSID.last`
				if [ $LASTEV -ne $NEWEV ]; then
					LASTEV=$NEWEV
					$RCLONE sync $CACHE_DIR/$CSID/ $CSID:/msync/ >> $CACHE_DIR/msync.log 2>&1
				fi
			fi
			sleep 30
		done
		
		exit 0
	;;
	install)
		check_root
		check_base
		if [ -z "$2" ]; then
			echo "'$1' command take one argument (see help)."
			exit -2
		fi
		CACHE_DIR=$2

		DRIVES=`grep -E '^\[.*\]$' /root/.rclone.conf | tr -d \[| tr -d \]`
		echo "You are going to setup msync with each entry found in rclone.conf :" $DRIVES
		echo "Caches will be stored in $CACHE_DIR"
		echo -n "Do you want to continue ? (y/n) "
		read response
		if [ $response != "y" ]; then
			echo "aborting."
			exit -4
		fi
		check_dir "$CACHE_DIR"
		for d in $DRIVES; do
			mkdir -p "$CACHE_DIR/$d"
		done
		echo "Done ! Run '$0 start $CACHE_DIR <mount point>' to start service"
		echo "ONLY if it is a first install."
		echo "If it is a re-install, first run '$0 import $CACHE_DIR' to"
		echo "retreive data (or all your data on cloud will be LOST !)."
		exit 0
	;;
	import)
		check_root
		check_base
		
		if [ -z "$2" ]; then
			echo "'$1' command take one argument (see help)."
			exit -2
		fi
		CACHE_DIR=$2
		
		DRIVES=`grep -E '^\[.*\]$' /root/.rclone.conf | tr -d \[| tr -d \]`
		

		for d in $DRIVES; do
			echo "Importing data from $d ..."
			$RCLONE sync  $d:/msync/ $CACHE_DIR/$d/ >> $CACHE_DIR/msync.log 2>&1
		done

		echo "Done ! You can now start the service using '$0 start $CACHE_DIR <mount point>'."
		exit 0
	;;
	start)
		check_root
		
		if [ -z "$2" ] || [ -z "$3" ]; then
			echo "'$1' command take two arguments (see help)."
			exit -2
		fi
		CACHE_DIR=`realpath $2`
		GLOBAL_MOUNT_POINT=`realpath $3`

		check_dir "$GLOBAL_MOUNT_POINT"
		
		DRIVES=`grep -E '^\[.*\]$' /root/.rclone.conf | tr -d \[| tr -d \]`
		
		echo "Aggregating cache directories ..."
		if [ -n "`mount|grep $GLOBAL_MOUNT_POINT|grep aufs`" ]; then
			echo "$GLOBAL_MOUNT_POINT already monted, aborting."
			exit -5
		fi
		DRVSTR="br="
		for d in $DRIVES; do
			DRVSTR="$DRVSTR$CACHE_DIR/$d=rw:"
		done
		modprobe aufs
		mount -t aufs -o $DRVSTR -o udba=reval -o create=rr none $GLOBAL_MOUNT_POINT
		
		echo "Starting msync services in background :"
		
		for d in $DRIVES; do
			echo -n " $d : "

			if [ -e $CACHE_DIR/.msync_$d.pid ]; then
				pid=`cat $CACHE_DIR/.msync_$d.pid`
				if [ `ps --pid $pid | wc -l` -eq 2 ]; then
					echo -n "sync (already running) "
				fi
			else
				$0 sync $CACHE_DIR $d >> $CACHE_DIR/msync.log 2>&1 &
				pid=$!
				echo $pid > $CACHE_DIR/.msync_$d.pid
				echo -n "sync "
			fi
			
			if [ -e $CACHE_DIR/.iwatch_$d.pid ]; then
				pid=`cat $CACHE_DIR/.iwatch_$d.pid`
				if [ `ps --pid $pid | wc -l` -eq 2 ]; then
					echo "iwatch (already running)"
				fi
			else
				iwatch -v -c "date +%N > $CACHE_DIR/.msync_$d.last" -r $CACHE_DIR/$d >> $CACHE_DIR/msync.log 2>&1 &
				pid=$!
				echo $pid > $CACHE_DIR/.iwatch_$d.pid
				echo "iwatch"
			fi
			
		done

		echo "Done ! You can use your global storage at $GLOBAL_MOUNT_POINT."
		exit 0
	;;
	stop)
		check_root
		
		if [ -z "$2" ] || [ -z "$3" ]; then
			echo "'$1' command take two arguments (see help)."
			exit -2
		fi
		CACHE_DIR=$2
		GLOBAL_MOUNT_POINT=$3
		
		echo -n "Stoping msync services : "
		PID_FILES=`ls -1 $CACHE_DIR/.*_*.pid 2> /dev/null`
		if [ -z "$PID_FILES" ]; then
			echo "Unable to find PID files, aborting."
			exit -6
		fi
		for pid_file in $PID_FILES; do
			pid=`cat $pid_file`
			if [ `ps --pid $pid | wc -l` -eq 2 ]; then
				kill $pid
			else
				echo "process $pid not running !"
			fi
			rm $pid_file
		done
		echo "ok"

		#GLOBAL_MOUNT_POINT=`mount|grep 'type aufs'|grep 'create=rr'|tr \  \\n|grep /`	
		umount $GLOBAL_MOUNT_POINT
		rmdir $GLOBAL_MOUNT_POINT
		echo "Done ! $GLOBAL_MOUNT_POINT should no longer be available."
		exit 0
	;;
	*)
		if [ -n "$1" ]; then
			echo "Unknown command '$1', try '$0 help'."
		else
			do_help
		fi
		exit -255
	;;	
esac
