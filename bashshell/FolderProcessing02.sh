#!/bin/bash
###################################################################
#Script Name    : FolderProcessing02
#Description    : 
# - zip folders in watch folder
# - write foldername.txt with contents of each zip file separately
# - move zipped file to upload folder 2
# - move original folder to archive folder and change timestamp for folder and all files to current time
# - write overall log and end script
#Version        : 1.0
#Notes          : None
###################################################################

_VERSION="FolderProcessing02 - 1.0"


#Root directory needed to run zip command
ROOT_PATH=(
    "/mnt/ajplus/Pipeline/_ARCHIVE_INDVCMS/ajplus"
)

# Log folder store application running log, report log
LOG_PATH="/mnt/ajplus/Admin/"

#back up folder
BACKUP_DIR="/mnt/ajplus/_OUT_Box/Zip_7day_Archive/"

#upload folder
UPLOAD_DMV="/mnt/ajplus/Admin/CMS/Upload_To_DMV_2/"

TOTAL_FOLDER=0

function DEBUG() {
  [ "$_DEBUG" == "dbg" ] && $@ || :
}

helpFunction() {
  echo ""
  echo "Script version : $_VERSION"
  echo "Usage: $0"
  echo -e "Example : ./FolderProcessing02.sh"
  exit 1
}

while getopts "c:" opt; do
  case "$opt" in
  c)
    clear_lock="$OPTARG"
    ;;
  ?) helpFunction ;;
  esac
done

# get file size
get_file_size() {
    echo $(stat -c%s "$1")
}

convert_size() {
    printf %s\\n $1 | LC_NUMERIC=en_US numfmt --to=iec
}

get_info_hierarchy() {
  local folder="$1"
  local log_file="$2"
  echo "========== FOLDER HIERARCHY INFO START ==========" >>"$log_file"
  tree --du -lah "$folder" >>"$log_file"
  echo "========== FOLDER HIERARCHY INFO END ==========" >>"$log_file"
  echo >>"$log_file"
}


################################################################################
# Main program                                                                 #
################################################################################

main(){
    # validate configuration value
    validate=0

    if [ ! -d "$BACKUP_DIR" ]; then
        printf "Warning! Directory doesn't existed [BACKUP_DIR][$BACKUP_DIR]\n"
        validate=1
    fi

    if [ ! -d "$UPLOAD_DMV" ]; then
        printf "Warning! Directory doesn't existed [UPLOAD_DMV_OVER][$UPLOAD_DMV]\n"
        validate=1
    fi

    if [[ -d "$ROOT_PATH" ]]; then
        echo "Input folder : [$ROOT_PATH]"
    else
        echo "Error! Input folder is invalid"
        helpFunction
        return
    fi

    if [ $validate -gt 0 ]; then
        echo "Some output folders do not exist. Please create those folders first"
        return
    fi

    # Zip all available folders in watch folder
    sub_dirs=$(find "$ROOT_PATH" -maxdepth 1 -type d | tail -n +2)
    while IFS= read -r dir; do
        if [ -z "$dir" ]; then
            continue
        fi
        TOTAL_FOLDER=$(($TOTAL_FOLDER + 1))
        echo
        echo "*** Processing sub folder ($(du -sh "$dir" | awk '{printf $1}')): $(basename "$dir")"
        folder_size=$(du -sb "$dir" | awk '{printf $1}')
        folder_name=$(echo $(basename "$dir"))
        dir_name=$(echo $(dirname "$dir"))

        if [[ $folder_name == "only drop folders of zip files. videos will be deleted" ]]; then
            echo "Ignore this folder due to internal rule"
            continue
        fi

        zip_file="$dir_name/$folder_name".zip

        folder_log="$LOG_PATH/$folder_name.txt"
        get_info_hierarchy "$dir" "$folder_log"

        echo "Start zipping:$folder_name.zip"
        zip -r $zip_file "$dir" >/dev/null 2>&1
        size=$(get_file_size "$zip_file")
            
        echo "Folder hierarchy log: $folder_log"
        echo "Moving zip file ($(convert_size "$size")) to: $(echo $(basename "$UPLOAD_DMV"))"
        mv -f "$zip_file" "$UPLOAD_DMV"

        echo "Moving original folder to: $(echo $(basename "$BACKUP_DIR"))"
        cp -rf "$dir" "$BACKUP_DIR"
        rm -rf "$dir"
    done < <(printf '%s\n' "$sub_dirs")
    echo
    echo "===================="
    printf "%10s %-20s : $TOTAL_FOLDER\n" "-" "Total folders"
    echo
    printf "%10s %-20s : $log_file \n" "-" "Log file"
    echo "===================="
    echo "Bye"
    
}

log_file="$LOG_PATH/folder_processing_01"$(date +%d%m%y_%H%M)".txt"

main $1 | while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done | tee "$log_file"

echo "Bye"