#!/bin/bash
###################################################################
#Script Name    : CopyFile                                                  
#Description    : This script will copy file by rule:
#                 If destination folde is empty , 20 files will be copied
#                 from source folder to destination folder
#Version        : 1.0
#Notes          : None                                             
#Author         : phongtran0715@gmail.com
###################################################################

# Source directory list
path_EN="/mnt/restore/TEST_COPY/EN"
path_ES="/mnt/restore/TEST_COPY/ES"
path_AR="/mnt/restore/TEST_COPY/AR"

# Destination  directory list
upload_EN="/mnt/restore/TEST_COPY/upload_EN"
upload_ES="/mnt/restore/TEST_COPY/upload_ES"
upload_AR="/mnt/restore/TEST_COPY/upload_AR"

SOURCE_DIR=( "$path_EN" "$path_ES" "$path_AR")
DEST_DIR=( "$upload_EN" "$upload_ES" "$upload_AR")

# Number of file will be copied each time
NUMBER_COPY_FILE=20
IS_BUSY=0

validate_folder(){
    if [ ! -d "$path_EN" ]; then 
        printf "Warning! Directory doesn't existed [$path_EN]\n"; fi
    if [ ! -d "$path_ES" ]; then 
        printf "Warning! Directory doesn't existed [$path_ES]\n"; fi
    if [ ! -d "$path_AR" ]; then 
        printf "Warning! Directory doesn't existed [$path_AR]\n"; fi
    
    if [ ! -d "$upload_EN" ]; then 
        printf "Warning! Directory doesn't existed [$upload_EN]\n"; fi
    if [ ! -d "$upload_ES" ]; then 
        printf "Warning! Directory doesn't existed [$upload_ES]\n"; fi
    if [ ! -d "$upload_AR" ]; then 
        printf "Warning! Directory doesn't existed [$upload_AR]\n"; fi
}

move_file(){
    local source_dir="$1"
    local dest_dir="$2"
    count=0
    if [ ! -d "$source_dir" ] || [ ! -d "$dest_dir" ]; then return; fi
    for entry in "$source_dir"/*
    do
        if [ $count -lt $NUMBER_COPY_FILE ];then
            mv -f "$entry" "$dest_dir"
            count=$((count + 1))
        else
            break
        fi
    done
    echo "$count file was copied from [$source_dir] to [$dest_dir]"
}
main(){
    validate_folder
    if [ $IS_BUSY -eq 0 ];then
        IS_BUSY=1
        for i in "${!DEST_DIR[@]}";do
            if [ -z "$(ls -A ${DEST_DIR[$i]} )" ]; then
                move_file "${SOURCE_DIR[$i]}" "${DEST_DIR[$i]}"
            fi
        done
        IS_BUSY=0
    fi    
}

main | while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done


