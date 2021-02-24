#!/bin/bash
###################################################################
#Script Name    : CopyData
#Description    : This script will copy data from
#                   source directory to target directorys
#
#Version        : 1.1
#Notes          : None
#Author         : phongtran0715@gmail.com
###################################################################

SOURCE_PATH="/mnt/restore/S3UPLOAD/TEMP-EN/"

AR_DEST_PATH="/mnt/restore/S3UPLOAD/AR_Prod_LTO/"
AR_SIZE=$((10 * 1024 * 1024 * 1024 * 1024)) #10Tb

ES_DEST_PATH="/mnt/restore/S3UPLOAD/ES_Prod_LTO/"
ES_SIZE=-1 # copy all remaing data

AR_COPIED_SIZE=0
ES_COPIED_SIZE=0

convert_size() {
    printf %s\\n $1 | LC_NUMERIC=en_US numfmt --to=iec
}

count_file() {
    echo $(ls "$1" | wc -l)
}

main() {
    total=0
    ar_folder=0
    ar_file=0
    es_folder=0
    es_file=0
    echo "Source directory : $SOURCE_PATH"
    echo

    # process sub folder at root dir
    sub_dirs=$(find "$SOURCE_PATH" -maxdepth 1 -type d | tail -n +2)
    while IFS= read -r dir; do
        folder_size=$(du -s "$dir/" | awk '{printf $1}')
        folder_size=$((folder_size * 1024))
        echo "Processing sub folder : $dir"
        if [ $AR_COPIED_SIZE -lt $AR_SIZE ]; then
            echo "Copy folder $(basename $dir) ($(convert_size $folder_size)) to $AR_DEST_PATH"
            cp -rf "$dir" "$AR_DEST_PATH"
            AR_COPIED_SIZE=$((AR_COPIED_SIZE + $folder_size))
            ar_folder=$((ar_folder + 1))
            ar_file=$((ar_file + $(count_file "$dir")))
        else
            echo "Copy folder $(basename $dir) ($(convert_size $folder_size)) to $ES_DEST_PATH"
            cp -rf "$dir" "$ES_DEST_PATH"
            ES_COPIED_SIZE=$((ES_COPIED_SIZE + $folder_size))
            es_folder=$((es_folder + 1))
            es_file=$((es_file + $(count_file "$dir")))
        fi
        echo
    done < <(printf '%s\n' "$sub_dirs")

    #process file at root dir
    files=$(find "$SOURCE_PATH" -maxdepth 1 -type f)
    while IFS= read -r file; do
        echo "Processing file : $file"
        file_size=$(stat -c%s "$file")
        if [ $AR_COPIED_SIZE -lt $AR_SIZE ]; then
            echo "Copy file $(basename $file) ($(convert_size $file_size)) to $AR_DEST_PATH"
            cp -rf "$file" "$AR_DEST_PATH"
            AR_COPIED_SIZE=$((AR_COPIED_SIZE + $folder_size))
            ar_file=$((ar_file + 1))
        else
            echo "Copy file $(basename $file) ($(convert_size $file_size)) to $ES_DEST_PATH"
            cp -rf "$file" "$ES_DEST_PATH"
            ES_COPIED_SIZE=$((ES_COPIED_SIZE + $folder_size))
            es_file=$((es_file + 1))
        fi
        echo
    done < <(printf '%s\n' "$files")
    echo "=============="
    printf "%10s %s \n" "-" "Total folder : $((ar_folder + es_folder))"
    printf "%10s %s \n" "-" "Total file : $((ar_file + es_file))"
    printf "%10s %s \n" "-" "Total size : $(convert_size $((AR_COPIED_SIZE + ES_COPIED_SIZE)))"
    echo
    printf "%10s %s \n" "+" "$AR_DEST_PATH"
    printf "%10s %s \n" "-" "$ar_folder folder were copied"
    printf "%10s %s \n" "-" "$ar_file files were copied"
    printf "%10s %s \n" "-" "$(convert_size $AR_COPIED_SIZE) was copied"
    echo
    printf "%10s %s \n" "+" "$ES_DEST_PATH"
    printf "%10s %s \n" "-" "$((es_folder)) folders were copied"
    printf "%10s %s \n" "-" "$es_file files were copied"
    printf "%10s %s \n" "-" "$(convert_size $ES_COPIED_SIZE) was copied"
    echo
}

main | while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done
