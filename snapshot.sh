#!/bin/bash

ROOT=/mnt/snapshot						# Root of the snapshot output tree
HOSTS=( nas server )						# Names of devices to back up (used as directory names)
SOURCES=( / root@192.168.3.209:/ )				# Directories or network paths to back up
LOGDIR=/run/snapshot						# Log file location

declare -A KEEP=( [day]=6 [week]=3 [month]=5 [halfyear]=3 )	# Number of backups to retain at each level

lastdisk=$(df $ROOT --output=used | tail -1)			# Get archive disk usage before backup
mkdir -p $LOGDIR

# Which level of backup to run?
#   Mon - Sat run Daily
#   1st Sunday of Jan or July run half-yearly
#   1st Sunday of other months run monthly
#   Other Sundays run weekly

if [ $(date +%u) -eq 7 ]
then
  if [ $(date +%-d) -le 7 ]
  then
    month=$(date +%-m)
    if [ $month -eq 1 ] || [ $month -eq 7 ]
    then
      mode="halfyear"
    else
      mode="month"
    fi
  else
    mode="week"
  fi
else
  mode="day"
fi

# Rotate the previous backups of the level (if any), discarding the oldest if the limit is reached

count=${#HOSTS[@]}
for (( i=0; i<${count}; i++ ));
do
  host=${HOSTS[$i]}
  source=${SOURCES[$i]}
  cd $ROOT
  echo "Run $i for $host from $source in mode $mode"
  if [ ! -d $host ]
  then
    echo "  Creating directory $host"
    mkdir $host
  fi
  cd $host
  if [ -d $mode.0 ]
  then
    echo "  Target directory $mode.0 exists"
    last=$(( KEEP[$mode] - 1 ))
    overflow=$mode.$last
    echo "  Overflow directory is $overflow"
    if [ -d $overflow ]
    then
      echo "  Deleting overflow directory $overflow"
      rm -rf $overflow
    fi
    for (( j=$last; j>0; j-- ));
    do
      k=$(( j - 1 ))
      if [ -d $mode.$k ]
      then
        echo "    Moving $mode.$k to $mode.$j"
        mv $mode.$k $mode.$j
      fi
    done
  fi

  previous=$(ls -t -1 | head -1)
  echo "  Previous backup is $previous"

# Create the new directory and carry out the backup.
# $ROOT/snapshot-exclusions should contain a list of directories / files to NOT back up - including $ROOT

  mkdir $mode.0
  rsync -av --delete --numeric-ids --relative --acls --stats --exclude-from=$ROOT/snapshot-exclusions \
        --link-dest=$ROOT/$host/$previous $source $mode.0/ &> $LOGDIR/$host.log
  status=$?

  if [ $status -eq 0 ]
  then
    touch $mode.0
  else
    echo "  Rsync completed with error $status"
    rm -rf $mode.0                                 # Delete backup on error, it will be re-created tomorrow.
  fi
done

# Report what we've done, including disk usage stats.

cd $LOGDIR
/usr/local/bin/snapreport.pl
diskused=$(df $ROOT --output=used | tail -1)
let "diff=$diskused-$lastdisk"
echo "Disk usage: $diskused ($diff)"

