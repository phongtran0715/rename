#!/bin/bash
###################################################################
#Script Name    : CopyFile
#Description    : This script will copy file by rule:
#                 If destination folde is empty , 20 files will be copied
#                 from source folder to destination folder
#Version        : 1.1
#Notes          : None
#Author         : phongtran0715@gmail.com
###################################################################

# Source directory list
path_EN="/mnt/restore/EN"
path_ES="/mnt/restore/ES"
path_AR="/mnt/restore/AR"

# Destination  directory list
upload_EN="/mnt/restore/TEST_COPY/upload_EN"
upload_ES="/mnt/restore/TEST_COPY/upload_ES"
upload_AR="/mnt/restore/TEST_COPY/upload_AR"

SOURCE_DIR=("$path_EN" "$path_ES" "$path_AR")
DEST_DIR=("$upload_EN" "$upload_ES" "$upload_AR")

# Number of file will be copied each time
NUMBER_COPY_FILE=20
IS_BUSY=0

FOLDER_SIZE_THRESHOLD=$((1 * 1024)) #Threshold 1Mb

validate_folder() {
    if [ ! -d "$path_EN" ]; then
        printf "Warning! Directory doesn't existed [$path_EN]\n"
    fi
    if [ ! -d "$path_ES" ]; then
        printf "Warning! Directory doesn't existed [$path_ES]\n"
    fi
    if [ ! -d "$path_AR" ]; then
        printf "Warning! Directory doesn't existed [$path_AR]\n"
    fi

    if [ ! -d "$upload_EN" ]; then
        printf "Warning! Directory doesn't existed [$upload_EN]\n"
    fi
    if [ ! -d "$upload_ES" ]; then
        printf "Warning! Directory doesn't existed [$upload_ES]\n"
    fi
    if [ ! -d "$upload_AR" ]; then
        printf "Warning! Directory doesn't existed [$upload_AR]\n"
    fi
}

move_file() {
    local s_dir="$1"
    local d_dir="$2"
    count=0
    if [ ! -d "$s_dir" ] || [ ! -d "$d_dir" ]; then return; fi
    # check source is empty
    if [ ! -z "$(find "$s_dir" -maxdepth 1 -type f)" ]; then
        for entry in "$s_dir"/*; do
            if [ $count -lt $NUMBER_COPY_FILE ]; then
                mv -f "$entry" "$d_dir"
                count=$((count + 1))
            else
                break
            fi
        done
    fi
    if [ $count -gt 0 ]; then
        echo "$count file was copied from [$s_dir] to [$d_dir]"
    fi
}

validate_sub_directory() {
    local dir="$1"
    dir_size=$(du -s "$dir" | awk '{printf $1}')
    if [ $dir_size -lt $FOLDER_SIZE_THRESHOLD ]; then
        echo "Removing folder $dir"
        rm -rf "$dir"
    fi
}

main() {
    validate_folder
    if [ $IS_BUSY -eq 0 ]; then
        IS_BUSY=1
        for i in "${!DEST_DIR[@]}"; do
            # Validate sub directory
            echo
            echo "Checking folder : ${DEST_DIR[$i]}"
            lines=$(find "${DEST_DIR[$i]}" -maxdepth 1 -type d | tail -n +2)
            while IFS= read -r d; do
                if [ -d "$d" ]; then
                    validate_sub_directory "$d"
                fi
            done < <(printf '%s\n' "$lines")

            #  check and copy file
            if [ -z "$(find "${DEST_DIR[$i]}" -maxdepth 1 -type f)" ]; then
                # no file existed
                move_file "${SOURCE_DIR[$i]}" "${DEST_DIR[$i]}"
            fi
        done
        IS_BUSY=0
    fi
}

main | while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done
