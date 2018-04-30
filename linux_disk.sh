#!/bin/bash

usage="$0 [-d] [-h]"

helpText="
NAME
    linux_disk

SYNOPSIS
$(echo "    $usage")

DESCRIPTION
    linux_disk checks the remaining space of disks (/dev/sd[a-z][1-9] /dev/mapper*),
    based on the size of the disk.

    Built primarily for use with OP5 monitoring system.

    The thresholds are defined within the script with these variables:
    ### Disk size limits in megabyte
    # default: 200 gigabyte (204800 Mb) 
    diskDefaultMb=204800
    # Huge disk:
    hugeDiskMb=1000000

    ### Warning and critical levels in percent
    # Defaults: disks < 200G
    warnDefault=15
    critDefault=10
    # Levels for disks >= 200G
    warnBigdisk=10
    critBigdisk=5
    # Levels for huge disks >= 1TB
    warnHugedisk=7
    critHugedisk=3

    Exit codes:
    0: No alerts
    1: Warning
    2: Critical
    3: No partitions to check
    4: Incorrect command line argument
    5: Incorrect percent value of mountpoint (not int or empty)

    Note that this check will ALWAYS exit with 2 (Critical) if ANY of 
    the partitions are in Critical level.
    In other words; if one disk is 'Warning' and the other is 
    'Critical', the value submitted to OP5 will be 'Critical'.

OPTIONS
    -h
        Show this help and exit
    -d
        Debug. Show information about all disks to stdout

AUTHOR
    Magnus Wallin (magnus.wallin@24solutions.com)

COPYRIGHT
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
"
# Control if we want to show ALL disks to stdout
debug=0

### Get command line options
while getopts ":dh" opt; do
    case $opt in
        d)
            debug=1
        ;;
        h)
            echo "$helpText" | less
            exit 0
        ;;
        \?)
            echo "Invalid option: -$OPTARG"
            exit 4
        ;;
    esac
done

shift $(($OPTIND-1))

# Exit directly if we don't have any partitions to check
if ! df | egrep -q '/dev/sd[a-z][1-9]?|mapper'; then
    echo "No disks to check. Exiting."
    exit 3
fi

### Disk size limits in megabyte
# default: 200 gigabyte (204800 Mb) 
diskDefaultMb=204800
# Huge disk:
hugeDiskMb=1000000

### Warning and critical levels in percent
# Defaults: disks < 200G
warnDefault=15
critDefault=10
# Levels for disks >= 200G
warnBigdisk=10
critBigdisk=5
# Levels for huge disks >= 1TB
warnHugedisk=7
critHugedisk=3

### Other variables
# Save disk information in this array
diskArray=()
# Store graph data in this string
graph=""
# Output string
output=""


# Loop and parse output from df
while read device size used free percent mountpoint; do
    # Get percent used, strip non-digits
    percUsed=$(echo $percent | grep -o '[0-9]*')
    # Sanity check the $percUsed variable
    if [[ ! "$percUsed" =~ [0-9]{1,2} ]]; then
        echo "Got incorrect size from $device. Exiting"
        exit 5
    fi
    # Calculate percent free
    percFree=$((100-$percUsed))
    # Check size of disk, if smaller than or equal to default,
    # compare against the default warning & critical values.
    if (( $size <= $diskDefaultMb )); then
        # Calculate graph data:
        # Warning:
        warnValueDefault=$(awk -v v1=$size 'BEGIN { print int(v1*0.85) }')
        # Critical:
        critValueDefault=$(awk -v v1=$size 'BEGIN { print int(v1*0.9) }')
        # Build graph string:
        graph+="$mountpoint=${used}MB;$warnValueDefault;$critValueDefault;0;$size "

        # Check against default values
        if (( $percFree <= $critDefault )); then
            diskArray+=("Critical: $percFree% left on $mountpoint ")
        elif (( $percFree <= $warnDefault )); then
            diskArray+=("Warning: $percFree% left on $mountpoint ")
        else
            diskArray+=("OK: $percFree% left on $mountpoint ")
        fi
    # Check if disk is >= default and < "huge"
    elif (( $size >= $diskDefaultMb && $size < $hugeDiskMb )); then
        # Calculate graph data:
        # Warning:
        warnValueBigdisk=$(awk -v v1=$size 'BEGIN { print int(v1*0.9) }')
        # Critical:
        critValueBigdisk=$(awk -v v1=$size 'BEGIN { print int(v1*0.95) }')
        # Build graph string:
        graph+="$mountpoint=${used}MB;$warnValueBigdisk;$critValueBigdisk;0;$size "

        # Check against values for big disks
        if (( $percFree <= $critBigdisk )); then
            diskArray+=("Critical: $percFree% left on $mountpoint ")
        elif (( $percFree <= $warnBigdisk )); then
            diskArray+=("Warning: $percFree% left on $mountpoint ")
        else
            diskArray+=("OK: $percFree% left on $mountpoint ")
        fi
    else
        # Calculate graph data:
        # Warning:
        warnValueHugedisk=$(awk -v v1=$size 'BEGIN { print int(v1*0.93) }')
        # Critical:
        critValueHugedisk=$(awk -v v1=$size 'BEGIN { print int(v1*0.97) }')
        # Build graph string:
        graph+="$mountpoint=${used}MB;$warnValueHugedisk;$critValueHugedisk;0;$size "

        # Check against values for "huge" disks
        if (( $percFree <= $critHugedisk )); then
            diskArray+=("Critical: $percFree% left on $mountpoint ")
        elif (( $percFree <= $warnHugedisk )); then
            diskArray+=("Warning: $percFree% left on $mountpoint ")
        else
            diskArray+=("OK: $percFree% left on $mountpoint ")
        fi
    fi
done < <(df -Pm | egrep '/dev/sd[a-z][1-9]?|mapper')
# Need -P (Posix) switch to prevent line breaks in df output.

# Create exit code by parsing the $diskArray
# If _any_ 'Critical', exit with 2.
# If we have a 'Warning', but no 'Critical' exit with 1.
# Else, exit with 0.
if echo "${diskArray[@]}" | grep -q 'Critical'; then
    exitCode=2
elif echo "${diskArray[@]}" | grep -q 'Warning'; then
    # If warning level is already Critical, leave it!
    if [[ $exitCode != 2 ]]; then
        exitCode=1
    fi
else
    exitCode=0
fi

### Print status to stdout
# If any disk is critical or warning...
if [[ $exitCode == 2 || $exitCode == 1 ]]; then
    # Loop diskArray and save the disks in string
    for disk in "${diskArray[@]}"; do
        if [[ $disk =~ ^Critical || $disk =~ ^Warning ]]; then
            output+="$disk"
        fi
    done
    if [[ $debug == 1 ]]; then
        echo -en "${diskArray[@]} | $graph\n"
        exit $exitCode
    fi
    echo -en "$output | $graph\n"
# Otherwise, print OK message
else
    if [[ $debug == 1 ]]; then
        echo -en "${diskArray[@]} | $graph\n"
        exit $exitCode
    fi
    echo -en "Disks OK | $graph\n"
fi

exit $exitCode
