#!/bin/sh

OLD_SUFFIX=$1
NEW_SUFFIX=$2
TARGET_FOLDER=$3

if [ "$#" -ne "3" ]
then
       exit 0
fi

find $TARGET_FOLDER -iname *.$OLD_SUFFIX -exec cp {} {}.old \;
find $TARGET_FOLDER -iname *.$OLD_SUFFIX -exec sed -i '1s/^/\<META HTTP-EQUIV="Content-Type" CONTENT="text\/html; charset=Shift_JIS"\>\n/' {} \;
find $TARGET_FOLDER -iname *.$OLD_SUFFIX -exec sed -i 's/$/\<br\/\>/' {} \;
find $TARGET_FOLDER -iname *.$OLD_SUFFIX -exec mv {} {}.$NEW_SUFFIX \;

exit 0 
