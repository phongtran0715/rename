#!/bin/bash
###################################################################
#Script Name    : CopyData                                                 
#Description    : This script will copy data from 
# 					source directory to target directorys
#                 
#Version        : 1.0
#Notes          : None                                             
#Author         : phongtran0715@gmail.com
###################################################################

SOURCE_PATH="/mnt/restore/S3UPLOAD/TEMP-EN/"

AR_DEST_PATH="/mnt/restore/S3UPLOAD/AR_Prod_LTO/"
AR_SIZE=$((10* 1024 * 1024 * 1024 * 1024)) #10Tb

ES_DEST_PATH="/mnt/restore/S3UPLOAD/ES_Prod_LTO/"
ES_SIZE=-1 # copy all remaing data

AR_COPIED_SIZE=0
ES_COPIED_SIZE=0

convert_size(){
  printf %s\\n $1 | LC_NUMERIC=en_US numfmt --to=iec
}

main(){
	total=0
	ar_file=0
	echo "Source directory : $SOURCE_PATH"
	files=$(ls -rS "$SOURCE_PATH"| egrep '\.zip$|\.Zip$|\.ZIP$')
	while IFS= read -r file; do
        file="$SOURCE_PATH/$file"
        if [ ! -f "$file" ];then continue;fi
        total=$((total+1))
    	zipSize=$(stat -c%s "$file")
        if [ $AR_COPIED_SIZE -lt $AR_SIZE ]; then
        	echo "Copy file $(basename $file) ($(convert_size $zipSize)) to $AR_DEST_PATH"
	    	cp -f "$file" "$AR_DEST_PATH"
	    	AR_COPIED_SIZE=$((AR_COPIED_SIZE + $zipSize))
	    	ar_file=$((ar_file + 1))
	    else
	    	echo "Copy file $(basename $file) ($(convert_size $zipSize)) to $ES_DEST_PATH"
	    	cp -f "$file" "$ES_DEST_PATH"
	    	ES_COPIED_SIZE=$((ES_COPIED_SIZE + $zipSize))
        fi
        echo
    done < <(printf '%s\n' "$files")
    echo "=============="
	printf "%10s %s \n" "-" "Total file : $total"
	echo
	printf "%10s %s \n" "-" "$ar_file files copied to $AR_DEST_PATH"
	printf "%10s %s \n" "-" "$(convert_size $AR_COPIED_SIZE) was copied to $AR_DEST_PATH"
	echo
	printf "%10s %s \n" "-" "$((total - ar_file)) files copied to $ES_DEST_PATH"
	printf "%10s %s \n" "-" "$(convert_size $ES_COPIED_SIZE) was copied to $ES_DEST_PATH"
	echo
}

main | while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done