#!/bin/bash
# Original Author: Trent Swanson - Full Scale 180 Inc github:(trentmswanson)
# Version: 0.1
# Url: https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/shared_scripts/ubuntu/vm-disk-utils-0.1.sh
#
# Modified By: Istvan Cebrian
# Date: 15/03/2016
# Version: 0.1
#
# Description:
#  This script automates the partitioning and formatting of data disks
#  according to provided input values which need to specify mountpoint along with datadisk size
#
# How To Use :
#  sudo ./datadisks.sh [mountpoint1]-[size1] [mountpoint2-size2] [mountpoint3-size3]
#
# Notes :
# - You can have as many mount points as required
# - This script has only been tested on Ubuntu 14.04 LTS and must be root
# - If parameters are incorrectly formatted, script will not handle error well!!

log()
{
    # Un-comment the following if you would like to enable logging to a service
    #curl -X POST -H "content-type:text/plain" --data-binary "${HOSTNAME} - $1" https://logs-01.loggly.com/inputs/<key>/tag/es-extension,${HOSTNAME}
    echo "$1"
}

if [ "${UID}" -ne 0 ];
then
    log "Script executed without root permissions"
    echo "You must be root to run this program." >&2
    exit 3
fi

#A set of disks to ignore from partitioning and formatting
BLACKLIST="/dev/sda|/dev/sdb"

# Base path for data disk mount points
DATA_BASE="/datadisks"

is_partitioned() {
    OUTPUT=$(partx -s ${1} 2>&1)
    egrep "partition table does not contains usable partitions|failed to read partition table" <<< "${OUTPUT}" >/dev/null 2>&1
    if [ ${?} -eq 0 ]; then
        return 1
    else
        return 0
    fi
}

has_filesystem() {
    DEVICE=${1}
    OUTPUT=$(file -L -s ${DEVICE})
    grep filesystem <<< "${OUTPUT}" > /dev/null 2>&1
    return ${?}
}

scan_for_new_disks() {
    # Looks for unpartitioned disks
    declare -a RET
    DEVS=($(ls -1 /dev/sd*|egrep -v "${BLACKLIST}"|egrep -v "[0-9]$"))
    for DEV in "${DEVS[@]}";
    do
        # The disk will be considered a candidate for partitioning
        # and formatting if it does not have a sd?1 entry or
        # if it does have an sd?1 entry and does not contain a filesystem
        is_partitioned "${DEV}"
        if [ ${?} -eq 0 ];
        then
            has_filesystem "${DEV}1"
            if [ ${?} -ne 0 ];
            then
                RET+=" ${DEV}"
            fi
        else
            RET+=" ${DEV}"
        fi
    done
    echo "${RET}"
}

add_to_fstab() {
    UUID=${1}
    MOUNTPOINT=${2}
    grep "${UUID}" /etc/fstab >/dev/null 2>&1
    if [ ${?} -eq 0 ];
    then
        echo "Not adding ${UUID} to fstab again (it's already there!)"
    else
        LINE="UUID=\"${UUID}\"\t${MOUNTPOINT}\text4\tnoatime,nodiratime,nodev,noexec,nosuid\t1 2"
        echo -e "${LINE}" >> /etc/fstab
    fi
}

do_partition() {
# This function creates one (1) primary partition on the
# disk, using all available space
    _disk=${1}
    _type=${2}
    if [ -z "${_type}" ]; then
        # default to Linux partition type (ie, ext3/ext4/xfs)
        _type=83
    fi
    echo "n
p
1


t
${_type}
w"| fdisk "${_disk}"

#
# Use the bash-specific $PIPESTATUS to ensure we get the correct exit code
# from fdisk and not from echo
if [ ${PIPESTATUS[1]} -ne 0 ];
then
    echo "An error occurred partitioning ${_disk}" >&2
    echo "I cannot continue" >&2
    exit 2
fi
}
#end do_partition

####################################### START


if [ "$#" -eq 0 ]; then
  log "Script requires inputs such as datadisk1.sh mountpoint1-size mountpoint2-size ..."
  exit 2
else
  MOUNT_POINTS=( "$@" )
  DISKS=($(scan_for_new_disks))
fi


if [ "${#DISKS}" -eq 0 ];
then
    log "No unpartitioned disks without filesystems detected"
    exit 1
fi

for DISK in "${DISKS[@]}";
do
    DISK_SIZE=($(blockdev --getsize64 ${DISK} | while read KB dummy;do echo $((KB/1024/1024/1024));done))
    #echo "Working on ${DISK} with size ${DISK_SIZE} Gb"

    for MOUNT_POINT in "${MOUNT_POINTS[@]}";
    do
        MOUNT_DIR=($(echo ${MOUNT_POINT} | cut -d'-' -f1))
        MOUNT_SIZE=($(echo ${MOUNT_POINT} | cut -d'-' -f2))
        #echo "Working on mount point ${MOUNT_DIR} with size ${MOUNT_SIZE}"

        if [ "${DISK_SIZE}" -eq "${MOUNT_SIZE}" ];
        then
            echo "Will mount disk ${DISK} with size ${DISK_SIZE}Gb in mount point /${MOUNT_DIR} for size ${MOUNT_SIZE}Gb"

            is_partitioned ${DISK}
            if [ ${?} -ne 0 ];
            then
                echo "${DISK} is not partitioned, partitioning"
                do_partition ${DISK}
            fi
            PARTITION=$(fdisk -l ${DISK}|grep -A 1 Device|tail -n 1|awk '{print $1}')
            has_filesystem ${PARTITION}
            if [ ${?} -ne 0 ];
            then
                 echo "Creating filesystem on ${PARTITION}."
                 mkfs -j -t ext4 ${PARTITION}
            fi

            echo "Next mount point appears to be ${MOUNT_DIR}"
            [ -d "/${MOUNT_DIR}" ] || mkdir -p "/${MOUNT_DIR}"
            read UUID FS_TYPE < <(blkid -u filesystem ${PARTITION}|awk -F "[= ]" '{print $3" "$5}'|tr -d "\"")
            add_to_fstab "${UUID}" "/${MOUNT_DIR}"
            echo "Mounting disk ${PARTITION} on /${MOUNT_DIR}"
            mount "/${MOUNT_DIR}"
        fi
    done

done
