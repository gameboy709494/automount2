#!/bin/bash
# This script mounts USB mass storage devices when they are plugged in
# and unmounts them when they are removed.
#
# Licensed under the GNU General Public License v2.0
#
# Copyright (c) 2016 Weiqi Chen.
# Copyright © 2004, 2005 Martin Dickopp
# Copyright © 2008, 2009, 2010 Rogério Theodoro de Brito
#
# Thanks for usbmount!
#
# This file is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY, to the extent permitted by law; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.

#set -e
#exec > /dev/null 2>&1

######################################################################
# Auxiliary functions

# Log a string via the syslog facility.
log()
{
    logger -t "automount2[$$]" -- "$1": "$2"
}

# Test if the first parameter is in the list given by the second
# parameter.
in_list(){
    for v in $2; do
        [ "$1" != "$v" ] || return 0
    done
    return 1
}

# Test if is the mountpoint already be mounted by another devices.
is_mounted_point(){
    while read -r device mount_point remainder;
    do
		mount_point_=$(printf "$mount_point")
        if [ "$1" = "$mount_point_" ]; then
            return 0
        fi

    done < /proc/mounts

    return 1

}

is_mounted_device(){

    while read -r device remainder;
    do
        if [ "$1" = "$device" ]; then
            return 0
        fi

    done < /proc/mounts

    return 1

}

## Acquire lock.
#log debug "trying to acquire lock /var/run/automount2/.mount.lock"
#lockfile-create --retry 3 /var/run/automount2/.mount || \
#    { log err "cannot acquire lock /var/run/automount2/.mount.lock"; exit 1; }
#trap '( lockfile-remove /var/run/automount2/.mount )' 0
#log debug "acquired lock /var/run/automount2/.mount.lock"


######################################################################
# Main program
ID_FS_TYPE="$1"
ID_FS_USAGE="$2"
ID_FS_UUID_ENC="$3"
#ID_PART_ENTRY_SIZE="$4"
ID_FS_LABEL_ENC="$4"
log info "Start with "$DEVNAME", actions:"$ACTION""
log info "TYPE:$ID_FS_TYPE USAGE:$ID_FS_USAGE UUID:$ID_FS_UUID_ENC LABEL:$ID_FS_LABEL_ENC"
# Default values for configuration variables.
MOUNT_POINT_ROOT="/media"
FILESYSTEMS="vfat ext2 ext3 ext4 ntfs f2fs"
MOUNTOPTIONS="sync,noexec,nodev,noatime,nodiratime"
FS_MOUNTOPTIONS=

## Per Policy 9.3.2, directories under /var/run have to be created
## after every reboot.
#if [ ! -e /var/run/automount2 ]; then
#     mkdir -p /var/run/automount2
#     log debug "creating /var/run/usbmount directory"
#fi


umask 022

if [ "$ACTION" = add ]; then


# Grab device information from device and "divide it"
#   FIXME: improvement: implement mounting by label (notice that labels
#   can contain spaces, which makes things a little bit less comfortable).

    USAGE="$ID_FS_USAGE"
    if ! echo $USAGE | egrep -q "(filesystem|disklabel)"; then
        log info ""$DEVNAME" does not contain a filesystem or disklabel"
        exit 0
    fi
#   SIZE="$ID_PART_ENTRY_SIZE"
#   if [ -z "$SIZE" ] || [ "$SIZE" -le "0" ]; then
#   log info ""$DEVNAME" have a no-size filesystem, ignored"
#   exit 0
#   fi
    FSTYPE="$ID_FS_TYPE"
	if [ -z "ID_FS_TYPE" ]; then
		log info "ignored no-filesystem "$DEVNAME""
		exit 0
	fi
    UUID="$ID_FS_UUID_ENC"
	LABEL_WITH_NO_BLANK="$ID_FS_LABEL_ENC"
	LABEL=$(printf "$LABEL_WITH_NO_BLANK")
#    # Try to use specifications in /etc/fstab first.
#    if egrep -q "^[[:blank:]]*$DEVNAME" /etc/fstab; then
#        log info "executing command: mount $DEVNAME"
#        mount $DEVNAME || log err "mount by DEVNAME with $DEVNAME wasn't successful; return code $?"
#		exit 0
#    elif grep -q "^[[:blank:]]*UUID=$UUID" /etc/fstab; then
#        log info "executing command: mount -U $UUID"
#        mount -U $UUID || log err "mount by UUID with $UUID wasn't successful; return code $?"
#		exit 0
#    else
#        log debug "$DEVNAME contains filesystem type $FSTYPE"
#		#continue
#	fi

	fstype=$FSTYPE
	if ! in_list "$fstype" "$FILESYSTEMS"; then
		log debug "skip "$DEVNAME" with filesystem "$FSTYPE""
		exit 0
	fi

	#To check if it's already mounted.
	if is_mounted_device $DEVNAME; then
		log err ""$DEVNAME" is already mounted"
		exit 1
	fi

	#decide to use LABEL or UUID as mount point.
	MOUNT_POINT=
	#echo label:$LABEL
	if [ -n "$LABEL" ]; then

		MAX_INDEX=16
		index=1
		MOUNT_POINT="${MOUNT_POINT_ROOT}/$LABEL"
		while is_mounted_point "$MOUNT_POINT";
		do
			MOUNT_POINT="${MOUNT_POINT_ROOT}/$LABEL$index"
		    log info ""$MOUNT_POINT" is already mounted."
		    if [ $index -gt $MAX_INDEX ]; then
		        log info "Already 16 mounted point with the same name, that's enought!"
				log info "using uuid as mount point."
		    	MOUNT_POINT="${MOUNT_POINT_ROOT}/$UUID"
				break
		    fi
		    let index++
		done

	else
		log info "$DEVNAME has no label."
		MOUNT_POINT="${MOUNT_POINT_ROOT}/$UUID"
	fi
	
	if is_mounted_point "$MOUNT_POINT"; then
		log err "Already with the same UUID device mounted at:"$MOUNT_POINT""
		exit 1
	fi
	log info "mounting $DEVNAME to \""$MOUNT_POINT"\""

	mkdir -p "$MOUNT_POINT"


	if [ $FSTYPE = "ntfs"]; then
#					/opt/automount2_helper.sh "$DEVNAME" "$MOUNT_POINT"  &
					udisksctl mount --block-device "$DEVNAME" --options async,noatime,flush --no-user-interaction
	elif [ $FSTYPE = "vfat"  ] || [ $FSTYPE = "msdos" ]; then
					mount "$DEVNAME" -o async,noatime,flush,uid=nobody,gid=nogroup,umask=0000  "$MOUNT_POINT"
	else
					mount "$DEVNAME" "$MOUNT_POINT"
					chown nobody:nogroup "$MOUNT_POINT"
					chmod 0777 "$MOUNT_POINT"
	fi


##if [ "$ACTION" = add ]; then
elif [ "$ACTION" = remove ]; then

	while read -r device mount_point fstype remainder;
	do
		if [ "$DEVNAME" = "$device" ]; then
#			if in_list "$fstype" "$FILESYSTEMS"; then
				_mount_point=$(printf "$mount_point")
				log info "executing command: umount -l \""$_mount_point"\""
				umount -l "$_mount_point"
				log info "remove mount_point if it's empty"
				rmdir "$_mount_point"
#			fi
		fi
	done < /proc/mounts


else
	log err "unexpected: action '$ACTION'"
	exit 1
fi

log debug "automount2.sh execution finished"
