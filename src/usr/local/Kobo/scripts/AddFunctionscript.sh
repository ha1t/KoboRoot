#!/bin/sh

source /usr/local/Kobo/scripts/common.sh

if [ ! -f ${CONFIG_FILE} ]; then
	exit 0 
fi

source $CONFIG_FILE

TMPFILE=`mktemp -t`
TMPFILE2=`mktemp -t`
SQLCOMFILE=`mktemp -t`
SQLCOMFILE2=`mktemp -t`
saveifs=$IFS

IFS="*"

if [ "$UnknownFolderShelfName" == "" ]; then
	UnknownFolderShelfName="その他"
fi

echo ".separator '$IFS'" >$SQLCOMFILE

echo "SELECT RowID,Title FROM content " >>$SQLCOMFILE
echo "WHERE " >>$SQLCOMFILE
echo "ContentType = 6 AND Accessibility <= 1 AND " >>$SQLCOMFILE
echo "(Attribution='著者不明' OR Attribution='' OR IFNULL(Attribution,'') = '') AND " >>$SQLCOMFILE
echo "(MimeType='application/x-cbz' OR MimeType='application/x-cbr' OR MimeType='application/pdf');" >>$SQLCOMFILE

cat $SQLCOMFILE | $DBEXE $DBFILE | sed -e "s/$IFS\[\(.\+\)\] \?\(.\+\)/$IFS\2$IFS\1/g" -e "t" -e "s/\$/$IFS-/g" >$TMPFILE

echo "BEGIN TRANSACTION;" >$SQLCOMFILE

cat $TMPFILE | while read rowid title attr; 
do
	if [ "$attr" != "-" ]; then
		title=`echo $title | sed -e "s/'/''/g" -`
		attr=`echo $attr | sed -e "s/'/''/g" -`
		echo "UPDATE content SET Title='$title',Attribution='$attr' WHERE RowId=$rowid;" >>$SQLCOMFILE
	fi
done

if [ "$UpdatePDFPageDirection" == "ON" ]; then
	echo "UPDATE content SET PageProgressDirection='rtl', EpubType=13 " >>$SQLCOMFILE
	echo "WHERE PageProgressDirection='default' AND ContentType=6 AND Accessibility <= 1 AND" >>$SQLCOMFILE
	echo "(MimeType='application/x-cbz' OR MimeType='application/pdf' OR MimeType='application/x-cbr');" >>$SQLCOMFILE
fi

if [ "$BookShelfReCreate" == "ON" ]; then
	#Delete Shelf And ShelfContent
	echo "DELETE FROM Shelf WHERE IFNULL(Type,'') <> 'Custom'; " >>$SQLCOMFILE
	echo "UPDATE Shelf SET _IsDeleted = 'true' WHERE Type = 'Custom'; " >>$SQLCOMFILE
	echo "DELETE FROM ShelfContent; " >>$SQLCOMFILE
fi


#Font Setting Update
if [ "$FontSettingUpdate" != "OFF" -a "$FontSettingTemplate" != "" ]; then
	if [ "$FontSettingReset" == "ON" ]; then
		echo "DELETE FROM content_settings" >>$SQLCOMFILE
		echo "WHERE content_settings.ContentID NOT LIKE '%$FontSettingTemplate%'; " >>$SQLCOMFILE
	fi

	echo "INSERT INTO content_settings " >>$SQLCOMFILE
	echo "SELECT  " >>$SQLCOMFILE
	echo "    SUB1.*,SUB2.* " >>$SQLCOMFILE
	echo "FROM " >>$SQLCOMFILE
	echo "    (SELECT " >>$SQLCOMFILE
	echo "        STRFTIME('%Y-%m-%dT%H:%MZ','now'), " >>$SQLCOMFILE
	echo "        content_settings.ReadingFontFamily,  " >>$SQLCOMFILE
	echo "        content_settings.ReadingFontSize,  " >>$SQLCOMFILE
	echo "        content_settings.ReadingAlignment,  " >>$SQLCOMFILE
	echo "        content_settings.ReadingLineHeight,  " >>$SQLCOMFILE
	echo "        content_settings.ReadingLeftMargin,  " >>$SQLCOMFILE
	echo "        content_settings.ReadingRightMargin,  " >>$SQLCOMFILE
	echo "        content_settings.ReadingPublisherMode,  " >>$SQLCOMFILE
	echo "        content_settings.ActivityFacebookShare " >>$SQLCOMFILE
	echo "    FROM " >>$SQLCOMFILE
	echo "        content_settings " >>$SQLCOMFILE
	echo "    INNER JOIN content ON " >>$SQLCOMFILE
	echo "        content_settings.ContentID=content.ContentID AND  " >>$SQLCOMFILE
	echo "        content_settings.ContentType=content.ContentType " >>$SQLCOMFILE
	echo "    WHERE " >>$SQLCOMFILE
	echo "        content.ContentID LIKE '%$FontSettingTemplate%' " >>$SQLCOMFILE
	echo "    LIMIT 1) AS SUB2 " >>$SQLCOMFILE
	echo "INNER JOIN " >>$SQLCOMFILE
	echo "    (SELECT " >>$SQLCOMFILE
	echo "        content.ContentID,content.ContentType " >>$SQLCOMFILE
	echo "    FROM " >>$SQLCOMFILE
	echo "        content " >>$SQLCOMFILE
	echo "    WHERE " >>$SQLCOMFILE
	echo "        ContentType = 6 AND Accessibility <= 1 AND ___ExpirationStatus <> 3 AND " >>$SQLCOMFILE
	echo "        IFNULL(content.___FileSize,0) > 0 AND " >>$SQLCOMFILE

	if [ "$FontSettingReset" == "OFF" ]; then
		if [ "$FontSettingUpdate" == "NOREAD" ]; then
			echo "        ReadStatus = 0 AND  " >>$SQLCOMFILE
		elif [ "$FontSettingUpdate" == "READING" ]; then
			echo "        ReadStatus <= 1 AND  " >>$SQLCOMFILE
		else
			echo "        1 = 1 AND  " >>$SQLCOMFILE
		fi
	fi

	echo "        MimeType='application/x-kobo-epub+zip' AND " >>$SQLCOMFILE
	echo "        content.ContentID NOT IN(SELECT ContentID FROM content_settings) " >>$SQLCOMFILE
	echo "        ) AS SUB1; " >>$SQLCOMFILE
fi

echo "COMMIT TRANSACTION;" >>$SQLCOMFILE

#Execute First Query
cat $SQLCOMFILE | $DBEXE $DBFILE

if [ "$DebugMode" == "ON" ]; then
	cp $SQLCOMFILE /mnt/onboard/sql1.tmp
fi


if [ "$AutoCreateBookShelf" != "OFF" -o "$BookShelfReCreate" == "ON" ]; then
	#Select Target Books
	echo ".separator '$IFS'" >$SQLCOMFILE2
	echo "SELECT DISTINCT REPLACE(ContentID,'file://','') AS pathname,ContentID,IFNULL(Series,'') AS Series," >>$SQLCOMFILE2

	if [ "$UnKnownShelfName" != "" ]; then
		echo "(CASE " >>$SQLCOMFILE2
		echo "    WHEN IFNULL(content.Attribution,'') ='' OR content.Attribution = '著者不明' OR content.Attribution = '' THEN '$UnKnownShelfName' " >>$SQLCOMFILE2
		echo "    ELSE content.Attribution " >>$SQLCOMFILE2
		echo "END) " >>$SQLCOMFILE2
	else
		echo "content.Attribution " >>$SQLCOMFILE2
	fi

	echo " FROM content " >>$SQLCOMFILE2
	echo "LEFT JOIN user ON content .___UserID = user.UserID " >>$SQLCOMFILE2

	echo "WHERE " >>$SQLCOMFILE2
	echo "ContentType = 6 AND Accessibility <= 1 AND ___ExpirationStatus <> 3 AND " >>$SQLCOMFILE2
	echo "content .___UserID <>'' AND SUBSTR(ContentID,1,18) <> 'file:///usr/local/' AND" >>$SQLCOMFILE2

	#Target Device Select
	if [ "$CreateShelfDevice" == "1" ]; then
		# Only InternalStrage
		echo "SUBSTR(ContentID,1,15) <> 'file:///mnt/sd/' AND " >>$SQLCOMFILE2
	elif [ "$CreateShelfDevice" == "2" ]; then
		# Only SD Card
		echo "SUBSTR(ContentID,1,15) = 'file:///mnt/sd/' AND " >>$SQLCOMFILE2
	else
		# AllData
		echo "1 = 1 AND " >>$SQLCOMFILE2
	fi

	#TargetBookType Select
	if [ "$CreateShelfTarget" == "1" ]; then
		#UserCreate Data Only
		echo "IFNULL(user.UserID,'') = '' AND " >>$SQLCOMFILE2
	elif [ "$CreateShelfTarget" == "2" ]; then
		#Buy Books Only
		echo "IFNULL(user.UserID,'') <> '' AND " >>$SQLCOMFILE2
	else
		#All Books
		echo "1 = 1 AND " >>$SQLCOMFILE2
	fi

	echo "IFNULL(content.___FileSize,0) > 0 " >>$SQLCOMFILE2

	if [ "$AutoCreateBookShelf" == "ATTR" -a "$UnKnownShelfName" == "" ]; then
		echo "AND content.Attribution <> '著者不明' AND IFNULL(content.Attribution,'') <>'' " >>$SQLCOMFILE2
	fi

	echo "AND content.ContentID NOT IN (SELECT ContentID FROM ShelfContent); " >>$SQLCOMFILE2

	cat $SQLCOMFILE2 | $DBEXE $DBFILE  >$TMPFILE2

	echo "BEGIN TRANSACTION;" >$SQLCOMFILE

	#Read TargetData
	cat $TMPFILE2 | while read pathname contentID series attribution; 
	do
		FPATH=`dirname $pathname`
		LASTDIR=`basename $FPATH`
		SHELFNAME=""

		if [ $LASTDIR == "onboard" -o $LASTDIR == "$InternalStrageBookFolder" -o $LASTDIR == "sd" ]; then
			LASTDIR=""
        fi

		if [ $LASTDIR == "." ]; then
			LASTDIR=$series
        fi

		if [ "$AutoCreateBookShelf" == "ATTR" ]; then
			SHELFNAME=$attribution
		elif [ "$AutoCreateBookShelf" == "FOLDER" ]; then
			if [ $LASTDIR != "" -a $LASTDIR != "." ]; then
				SHELFNAME=$LASTDIR
			else
				SHELFNAME=$UnknownFolderShelfName
			fi
		elif [ "$AutoCreateBookShelf" == "MIXED" ]; then
			if [ $LASTDIR != "" -a $LASTDIR != "." ]; then
				if [ $LASTDIR != $attribution ]; then
					SHELFNAME="$attribution - $LASTDIR -"
				else
					SHELFNAME="$attribution - $UnknownFolderShelfName -"
				fi
			else
				SHELFNAME="$attribution - $UnknownFolderShelfName -"
			fi
		else
			SHELFNAME=""
		fi

		if [ $SHELFNAME != "" ]; then
			SHELFNAME=`echo $SHELFNAME | sed -e "s/'/''/g" -`
			contentID=`echo $contentID | sed -e "s/'/''/g" -`
		    echo "INSERT INTO ShelfContent SELECT '$SHELFNAME','$contentID',STRFTIME('%Y-%m-%dT%H:%M:%f','now'),'false','false';" >>$SQLCOMFILE
		fi
	done

	#Create New Shelf
	echo "INSERT INTO Shelf " >>$SQLCOMFILE
	echo "SELECT  " >>$SQLCOMFILE
	echo "    STRFTIME('%Y-%m-%dT%H:%M:%f','now'), " >>$SQLCOMFILE
	echo "    Sub1.ShelfName,Sub1.ShelfName, " >>$SQLCOMFILE
	echo "    STRFTIME('%Y-%m-%dT%H:%M:%f','now'), " >>$SQLCOMFILE
	echo "    Sub1.ShelfName,NULL,'false','true','false' " >>$SQLCOMFILE
	echo "FROM " >>$SQLCOMFILE
	echo "	(SELECT DISTINCT " >>$SQLCOMFILE
	echo "	    ShelfContent.ShelfName " >>$SQLCOMFILE
	echo "	FROM " >>$SQLCOMFILE
	echo "	    ShelfContent " >>$SQLCOMFILE
	echo "	WHERE " >>$SQLCOMFILE
	echo "	    ShelfContent.ShelfName NOT IN(SELECT Name FROM Shelf WHERE _IsDeleted='false')) AS Sub1; " >>$SQLCOMFILE

	echo "COMMIT TRANSACTION;" >>$SQLCOMFILE

	#Execute ShelfCreate Query
	cat $SQLCOMFILE | $DBEXE $DBFILE
fi


IFS=$saveifs

if [ "$DebugMode" == "ON" ]; then
	cp $SQLCOMFILE /mnt/onboard/sql.tmp
	cp $SQLCOMFILE2 /mnt/onboard/sql2.tmp
	cp $TMPFILE /mnt/onboard/sqlresult.tmp
	cp $TMPFILE2 /mnt/onboard/sqlresult2.tmp
fi

rm -rf $TMPFILE
rm -rf $TMPFILE2
rm -rf $SQLCOMFILE
rm -rf $SQLCOMFILE2
