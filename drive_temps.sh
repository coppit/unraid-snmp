#!/usr/bin/bash

MDCMD=/root/mdcmd
AWK=/usr/bin/awk
CAT=/usr/bin/cat
FIND=/usr/bin/find
GREP=/usr/bin/grep
RM=/usr/bin/rm
SED=/usr/bin/sed
HDPARM=/usr/sbin/hdparm
SMARTCTL=/usr/sbin/smartctl

CACHE=/tmp/plugins/snmp/drive_temps.txt

mkdir -p $(dirname $CACHE)

# Cache the results for 5 minutes at a time, to speed up queries
if $FIND $(dirname $CACHE) -mmin -5 -name drive_temps.txt | $GREP -q drive_temps.txt
then
  $CAT $CACHE
  exit 0
fi

$RM -f $CACHE

$MDCMD status | $GREP '\(rdevId\|rdevName\).*=.' | while read -r device
do
  read -r name

  # Double-check the data to make sure it's in sync
  device_num=$(echo $device | $SED 's#.*\.\(.*\)=.*#\1#')
  name_num=$(echo $name | $SED 's#.*\.\(.*\)=.*#\1#')

  if [[ "$device_num" != "$name_num" ]]
  then
    echo 'ERROR! Couldn'"'"'t parse mdcmd output. Command was:'
    echo 'mdcmd status | $GREP '"'"'\(rdevId\|rdevName\).*=.'"'"' | while read -r device'
  fi

  device=$(echo $device | $SED 's#.*=#/dev/#')
  name=$(echo $name | $SED 's/.*=//')

  if ! $HDPARM -C $device 2>&1 | $GREP -cq standby
  then
    temp=$($SMARTCTL -A $device | $GREP -m 1 -i Temperature_Celsius | $AWK '{print $10}')
  fi

  # For debugging
#  echo "$name = $device, $temp"

  echo "$name: $temp" >> $CACHE
done

$CAT $CACHE
exit 0
