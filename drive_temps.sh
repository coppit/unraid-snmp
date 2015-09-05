#!/usr/bin/bash

MDCMD=/usr/local/sbin/mdcmd
AWK=/usr/bin/awk
CAT=/usr/bin/cat
ECHO=/usr/bin/echo
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
  device_num=$($ECHO $device | $SED 's#.*\.\(.*\)=.*#\1#')
  name_num=$($ECHO $name | $SED 's#.*\.\(.*\)=.*#\1#')

  if [[ "$device_num" != "$name_num" ]]
  then
    $ECHO 'ERROR! Couldn'"'"'t parse mdcmd output. Command was:'
    $ECHO "$MDCMD status | $GREP '\(rdevId\|rdevName\).*=.' | while read -r device"
  fi

  device=$($ECHO $device | $SED 's#.*=#/dev/#')
  name=$($ECHO $name | $SED 's/.*=//')

  # Guzzi reports that it doesn't work for him with this guard code. I tested it and on my systems the drives don't spin
  # up. Perhaps this behavior changed from when the code I stole was first written. :)
  # https://lime-technology.com/forum/index.php?topic=41019.msg403695#msg403695
#  if ! $HDPARM -C $device 2>&1 | $GREP -cq standby
#  then
    temp=$($SMARTCTL -A $device | $GREP -m 1 -i Temperature_Celsius | $AWK '{print $10}')
#  fi

  # For debugging
#  $ECHO "$name = $device, $temp"

  $ECHO "$name: $temp" >> $CACHE
done

$CAT $CACHE
exit 0
