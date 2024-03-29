#!/bin/bash
###################################################################
#Script Name    : SpiltFolder
#Description    : Split parent folers based on folder zise and zip child folders
#Version        : 1.7
#Notes          : None
#Author         : phongtran0715@gmail.com
###################################################################

_VERSION="SplitFolder - 1.7"

#Root directory needed to run zip command
ROOT_PATH=(
	"/mnt/ajplus/Pipeline/_ARCHIVE_INDVCMS/ajplus"
)

# Directory hold unsuccesful zip folder
FAIL_PATH="/mnt/ajplus/Admin/CMS/zipX/Failed/"

# Log folder store application running log, report log
LOG_PATH="/mnt/ajplus/Admin/"

#back up folder
BACKUP_DIR="/mnt/ajplus/_OUT_Box/Zip_7day_Archive/"

#upload folder 1 (zip under 750gb)
UPLOAD_DMV_UNDER="/mnt/ajplus/Admin/CMS/Upload_To_DMV_1/"

#upload folder 2 (zip over 750gb)
UPLOAD_DMV_OVER="/mnt/ajplus/Admin/CMS/Upload_To_DMV_2/"

#This folder stores all folders that have size small than threshold size
DELETED_DIR="/mnt/restore/__DEL/"

# deleted folder size threshold value (equivalent to bytes)
# input folder with size smaller than the threshold will be deleted
# FOLDER_SIZE_THRESHOLD=$((50 * 1024 * 1024)) #50Mb
FOLDER_SIZE_THRESHOLD=$((750 * 1024 * 1024 * 1024 * 1024)) #750GiB

TOTAL_FOLDER=0
TOTAL_PROCESSED_FOLDER=0
TOTAL_FAILED_FOLDER=0
TOTAL_IGNORED_FOLDER=0

function DEBUG() {
  [ "$_DEBUG" == "dbg" ] && $@ || :
}

helpFunction() {
  echo ""
  echo "Script version : $_VERSION"
  echo "Usage: $0"
  echo -e "Example : ./SplitFolder.sh"
  echo -e "option:"
  echo -e "\t-c clear all lock file (yes/no). Default is no"
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

################################################################################
# Main program                                                                 #
################################################################################

main(){
	echo "Script version : $_VERSION"
	
  # validate configuration value
  validate=0
  if [ ! -d "$FAIL_PATH" ]; then
    printf "Warning! Directory doesn't existed [FAIL_PATH][$FAIL_PATH]\n"
    validate=1
  fi

  if [ ! -d "$BACKUP_DIR" ]; then
    printf "Warning! Directory doesn't existed [BACKUP_DIR][$BACKUP_DIR]\n"
    validate=1
  fi

  if [ ! -d "$UPLOAD_DMV_UNDER" ]; then
    printf "Warning! Directory doesn't existed [UPLOAD_DMV_UNDER][$UPLOAD_DMV_UNDER]\n"
    validate=1
  fi

  if [ ! -d "$UPLOAD_DMV_OVER" ]; then
    printf "Warning! Directory doesn't existed [UPLOAD_DMV_OVER][$UPLOAD_DMV_OVER]\n"
    validate=1
  fi

  if [ ! -d "$DELETED_DIR" ]; then
    printf "Warning! Directory doesn't existed [DELETED_DIR][$DELETED_DIR]\n"
    validate=1
  fi

	if [[ -d "$ROOT_PATH" ]]; then
		echo "Input folder : [$ROOT_PATH]"
	else
		echo "Error! Input folder is invalid"
		helpFunction
		return
	fi

	# Move file to fail folder
	find "$ROOT_PATH" -maxdepth 1 -type f -print0 | xargs -0 mv -ft "$FAIL_PATH" 2>/dev/null
	sub_dirs=$(find "$ROOT_PATH" -maxdepth 1 -type d | tail -n +2)
	while IFS= read -r dir; do
		if [ -z "$dir" ]; then
			continue
		fi
		TOTAL_FOLDER=$(($TOTAL_FOLDER + 1))
		echo
		echo "*** Processing sub folder ($(du -sh $dir | awk '{printf $1}')): $(basename $dir)"
		folder_size=$(du -sb $dir | awk '{printf $1}')
		folder_name=$(echo $(basename "$dir"))
		dir_name=$(echo $(dirname "$dir"))
		lock_file="/tmp/"$folder_name"_splitfolder.lock"

		if [ -f "$lock_file" ]; then
			echo "This folder is busy... Skipping!"
			continue
		else
			touch "$lock_file"
		fi

		if [ $folder_size -lt $FOLDER_SIZE_THRESHOLD ]; then
			TOTAL_UNDER_FOLDER=$(($TOTAL_UNDER_FOLDER + 1))

			zip_file="$dir_name/$folder_name".zip
			echo "Start zipping:$folder_name.zip"
			zip -r $zip_file "$dir" >/dev/null 2>&1
			size=$(get_file_size "$zip_file")
			echo "Moving zip file ($(convert_size "$size")) to: $(echo $(basename "$UPLOAD_DMV_UNDER"))"
			mv -f "$zip_file" "$UPLOAD_DMV_UNDER"
		else
			TOTAL_OVER_FOLDER=$(($TOTAL_OVER_FOLDER + 1))

			zip_file="$dir_name/$folder_name".zip
			echo "Start zipping:$folder_name.zip"
			zip -r "$zip_file" "$dir" >/dev/null 2>&1
			size=$(get_file_size "$zip_file")
			echo "Moving zip file ($(convert_size "$size")) to: $(echo $(basename "$UPLOAD_DMV_OVER"))"
			mv -f "$zip_file" "$UPLOAD_DMV_OVER"
		fi
		echo "Moving original folder to backup folder"
		cp -rf "$dir" "$BACKUP_DIR"
		rm -rf "$dir"

		rm -rf "$lock_file"
		echo "Finish procesing"
	done < <(printf '%s\n' "$sub_dirs")
	echo "===================="
	printf "%10s %-20s : $TOTAL_FOLDER\n" "-" "Total folders"
	printf "%10s %-20s : $TOTAL_UNDER_FOLDER\n" "-" "Under threshold folders"
	printf "%10s %-20s : $TOTAL_OVER_FOLDER\n" "-" "Over threshold folders"
	echo
	printf "%10s %-20s : $log_file \n" "-" "Log file"
	echo "===================="
	echo "Bye"
}

log_file="$LOG_PATH/split_folder_log_"$(date +%d%m%y_%H%M)".txt"

main $1 | while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done | tee "$log_file"

echo "Bye"