#!/bin/sh

MNG_FILE="/etc/images/boot/boot.mng"
PRODUCT=`/bin/kobo_config.sh`;
[ $PRODUCT != trilogy ] && PREFIX=$PRODUCT-

if [ -f ${MNG_FILE} ]; then
	trap_term_handler() {
		usleep 1
		trap '' TERM
		killall fbmngplay
		exit 1
	}

	trap trap_term_handler TERM
	/usr/local/Kobo/fbmngplay $MNG_FILE & wait
else
	i=0;
	while true; do
	        i=$((((i + 1)) % 11));
	        zcat /etc/images/$PREFIX\on-$i.raw.gz | /usr/local/Kobo/pickel showpic 1;
	        usleep 250000;
	done 
fi
