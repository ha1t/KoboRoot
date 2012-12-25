#!/bin/sh

MODE=$1

if [ "$#" -ne "1" ]
then
       exit 0
fi

source /usr/local/Kobo/scripts/common.sh

if [ ! -f ${CONFIG_FILE} ]; then
	exit 0 
fi

source $CONFIG_FILE

if [ "$UseJournalMode" == "ON" ]; then
	if [ "$MODE" = "ON" ]
	then
		$DBEXE $DBFILE 'PRAGMA journal_mode=WAL'
	elif [ "$MODE" = "OFF" ]
	then
		$DBEXE $DBFILE 'PRAGMA journal_mode=delete'
	fi
else
	$DBEXE $DBFILE 'PRAGMA journal_mode=delete'
fi

exit 0 
