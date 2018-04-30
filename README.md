# linux_disk
OP5 dynamic disk check for Linux partitions

Usage
```
NAME
    linux_disk

SYNOPSIS
    ./linux_disk.sh [-d] [-h]

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
```

