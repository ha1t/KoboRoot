#!/bin/sh
source /usr/local/Kobo/scripts/common.sh

if [ ! -f ${CONFIG_FILE} ]; then
	exit 0 
fi

source $CONFIG_FILE

if [ "$AutoConvertZip2CBZ" == "ON" ]; then
	if [ "$InternalStrageBookFolder" != "" -a "$InternalStrageBookFolder" != ".kobo" ]; then
		/usr/local/Kobo/scripts/convert_extension.sh zip cbz /mnt/onboard/$InternalStrageBookFolder
		/usr/local/Kobo/scripts/convert_extension.sh rar cbr /mnt/onboard/$InternalStrageBookFolder
	fi
fi

if [ "$AutoConvertText2HTML" == "ON" ]; then
	if [ "$InternalStrageBookFolder" != "" -a "$InternalStrageBookFolder" != ".kobo" ]; then
		/usr/local/Kobo/scripts/convert_txt2html.sh txt html /mnt/onboard/$InternalStrageBookFolder
	fi
fi
