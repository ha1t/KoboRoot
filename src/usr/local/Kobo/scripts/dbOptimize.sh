#!/bin/sh

source /usr/local/Kobo/scripts/common.sh

if [ ! -f ${CONFIG_FILE} ]; then
	exit 0 
fi

SQLCOMFILE=`mktemp -t`

/usr/local/Kobo/scripts/ChangeJournalMode.sh OFF

echo "REINDEX; " >$SQLCOMFILE
echo "ANALYZE; " >>$SQLCOMFILE
echo "VACUUM; " >>$SQLCOMFILE

cat $SQLCOMFILE | $DBEXE $DBFILE

rm -rf $SQLCOMFILE

/usr/local/Kobo/scripts/ChangeJournalMode.sh ON

