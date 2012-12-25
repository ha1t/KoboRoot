#!/bin/sh

MNG_FILE="/mnt/onboard/.images/dbupdate.mng"

PRODUCT=`/bin/kobo_config.sh`;
[ $PRODUCT != trilogy ] && PREFIX=$PRODUCT-

trap_term_handler() {
	usleep 1
	trap '' TERM
	killall fbmngplay
	exit 1
}

trap trap_term_handler TERM

if [ -f ${MNG_FILE} ]; then
	/usr/local/Kobo/fbmngplay $MNG_FILE & wait
else
	/usr/local/Kobo/fbmngplay /etc/images/$PREFIX\update-data.mng & wait
fi
