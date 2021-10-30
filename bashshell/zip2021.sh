#!/bin/bash

_VERSION="ZipFolder - 1.5"

# Root directory needed to run zip command
ROOT_PATH=(
	"/mnt/ajplus/Pipeline/_ARCHIVE_INDVCMS/ajplus"
	"/mnt/ajplus/Pipeline/_ARCHIVE_INDVCMS/ajplus_2"
)

# Directory hold unsuccesful zip folder
FAIL_PATH="/mnt/ajplus/Admin/CMS/zipX/Failed/"

# Directory hold zip file that have file size >= Threshold
OVER_THRESHOLD_PATH="/mnt/ajplus/Admin/CMS/Upload_To_DMV_2/"

# Directory hold zip file that have file size < Threshold
UNDER_THRESHOLD_PATH="/mnt/ajplus/_OUT_Box/Upload_To_DMV/"

# Log file directory
LOG_PATH="/mnt/ajplus/Admin/CMS/zipX/Logs"

# Directory hold all input folders
ARCHIVE_PATH="/mnt/ajplus/_OUT_Box/Zip_7day_Archive/"

# File size threshold value
FILE_SIZE_THRESHOLD=$((50 * 1024 * 1024)) #50Mb

LOCK_FILE="/tmp/zip2021.lock"

################################################################################
# Validate input argument                                                      #
################################################################################
[ -z "$ROOT_PATH" ] && echo "Missing root folder path " && exit
[ -z "$FAIL_PATH" ] && echo "Missing fail folder path " && exit
[ -z "$OVER_THRESHOLD_PATH" ] && echo "Missing over threshold folder path " && exit
[ -z "$UNDER_THRESHOLD_PATH" ] && echo "Missing under threshold folder path " && exit

helpFunction() {
	echo ""
	echo "Script version : $_VERSION"
	echo "Usage: $0 [option] "
	echo -e "Example : ./zip2021.sh"
	echo -e "option:"
	echo -e "\t-v Validate zip file before processing (yes/no). Default is no"
	exit 1
}

while getopts "v:" opt; do
	case "$opt" in
	v) validate_flag="$OPTARG" ;;
	?) helpFunction ;;
	esac
done

archive_folder() {
	local origin_folder="$1"
	local log_file="$2"
	echo "========== ARCHIVE INFO START ==========" >>"$log_file"
	echo "["$(date +"%m-%d-%Y %T %Z")"] Start archive folder : $origin_folder " >>"$log_file"
	# change latest modification date
	touch "$origin_folder/"
	files=$(ls -S "$origin_folder")
	while IFS= read -r file; do
		file="$origin_folder/$file"
		if [ ! -f "$file" ]; then continue; fi
		touch "$file"
	done < <(printf '%s\n' "$files")

	cp -rf "$origin_folder" "$ARCHIVE_PATH"
	rm -rf "$origin_folder"
	echo "["$(date +"%m-%d-%Y %T %Z")"] Finish archive" >>"$log_file"
	echo "========== DELETE INFO END ==========" >>"$log_file"
	echo >>"$log_file"
}

move_zip_file() {
	echo "========== ZIP FILE MOVEMENT START ==========" >>"$3"
	# cp "$1" "$ARCHIVE_PATH"
	# echo "["$(date +"%m-%d-%Y %T %Z")"] Zipped file was copied to : ["$ARCHIVE_PATH"]" >> "$3"
	mv "$1" "$2"
	echo "["$(date +"%m-%d-%Y %T %Z")"] Zipped file was moved to : ["$2"]" >>"$3"
	echo "========== ZIP FILE MOVEMENT END ==========" >>"$3"
	echo >>"$3"
}

move_fail_folder() {
	echo "========== ZIP FILE MOVEMENT START ==========" >>"$3"
	echo "Failed zip folder : $1" | tee -a "$3"
	mv "$1" "$2"
	echo "["$(date +"%m-%d-%Y %T %Z")"] Failed zip folder was moved to : ["$2"]" >>"$3"
	echo "========== ZIP FILE MOVEMENT END ==========" >>"$3"
	echo >>"$3"
}

get_info_hierarchy() {
	echo "========== FOLDER HIERARCHY INFO START ==========" >>"$2"
	echo "Directory size : " $(du -sh "$1") >>"$2"
	echo "Number of file : " $(find "$1" -type f -print | wc -l) >>"$2"
	echo "Number of directory : " $(find "$1" -type d -print | wc -l) >>"$2"
	echo >>"$2"
	du -alh "$1" >>"$2"
	echo "========== FOLDER HIERARCHY INFO END ==========" >>"$2"
	echo >>"$2"
}

convert_size() {
	printf %s\\n $1 | LC_NUMERIC=en_US numfmt --to=iec
}

validate_zip() {
	local file_path="$1"
	echo -e "Validating zip file : $file_path"
	result=$(zip -T "$file_path") >/dev/null
	echo "$result"
}

get_folder_size(){
	local folder="$1"
	echo $(stat -c%s "$1")
}

TOTAL_DIR=0
FALSE_DIR=0
OVER_THRESHOLD_COUNT=0
UNDER_THRESHOLD_COUNT=0
INVALID_ZIP=0
TOTAL_ZIP_SIZE=0

zip_execute() {
	if [ ! -d "$1" ]; then
		echo "Directory " $1 "DOES NOT exists."
		return
	fi
	for f in "$1/"*; do
		if [ -d "$f" ]; then
			TOTAL_DIR=$((TOTAL_DIR + 1))
			DIR_NAME=$(basename -- "$f")
			# remove space from dir name
			STANDARD_DIR_NAME=$(echo $DIR_NAME | tr -d ' ')
			ZIP_FILE="$1/$STANDARD_DIR_NAME".zip
			LOG_FILE="$LOG_PATH/$STANDARD_DIR_NAME".txt
			echo "" >"$LOG_FILE"

			get_info_hierarchy "$1/$DIR_NAME" "$LOG_FILE"

			echo "========== COMPRESS INFO START ==========" >>"$LOG_FILE"
			echo "($TOTAL_DIR)Processing : $(du -sh "$1/$DIR_NAME")" | tee -a "$LOG_FILE"
			echo "["$(date +"%m-%d-%Y %T %Z")"] Start compress" >>"$LOG_FILE"
			zip -r $ZIP_FILE "$f" >/dev/null 2>&1

			if [ $? -eq 0 ]; then
				FILE_SIZE=$(stat -c%s "$ZIP_FILE")
				echo "Zip successfully processed - Output file size : $(convert_size $FILE_SIZE)"
				if [[ $validate_flag == "yes" ]]; then
					is_valid=$(validate_zip "$ZIP_FILE")
				else
					is_valid="OK"
				fi

				if [[ $is_valid == *"OK"* ]]; then
					if [[ $validate_flag == "yes" ]]; then
						echo -e "Zip file is valid."
					fi
					echo "$1/$DIR_NAME, $STANDARD_DIR_NAME".zip, " $(convert_size $TOTAL_ZIP_SIZE)" >>"$SUMMARY_LOG"
					TOTAL_ZIP_SIZE=$(($TOTAL_ZIP_SIZE + $FILE_SIZE))
					if [ $FILE_SIZE -ge $FILE_SIZE_THRESHOLD ]; then
						OVER_THRESHOLD_COUNT=$((OVER_THRESHOLD_COUNT + 1))
						move_zip_file "$ZIP_FILE" "$OVER_THRESHOLD_PATH" "$LOG_FILE"
						echo "Move file to $OVER_THRESHOLD_PATH"
					else
						UNDER_THRESHOLD_COUNT=$((UNDER_THRESHOLD_COUNT + 1))
						move_zip_file "$ZIP_FILE" "$UNDER_THRESHOLD_PATH" "$LOG_FILE"
						echo "Move file to $UNDER_THRESHOLD_PATH"
					fi
				else
					echo "Invalid zip file (corrupted or unreadable)"
					INVALID_ZIP=$((INVALID_ZIP + 1))
					move_fail_folder "$ZIP_FILE" "$FAIL_PATH" "$LOG_FILE"
				fi
				echo "["$(date +"%m-%d-%Y %T %Z")"] Finish compress" >>"$LOG_FILE"
				echo "========== COMPRESS INFO END ==========" >>"$LOG_FILE"
				echo >>"$LOG_FILE"
				archive_folder "$1/$DIR_NAME/" "$LOG_FILE"
			else
				echo "========== COMPRESS INFO END ==========" >>"$LOG_FILE"
				move_fail_folder "$1/$DIR_NAME" "$FAIL_PATH" "$LOG_FILE"
				echo "$DIR_NAME, [FAILED]" >>"$SUMMARY_LOG"
				FALSE_DIR=$((FALSE_DIR + 1))
			fi

			echo "Log file : $LOG_FILE"
			echo
		fi
	done
}

is_script_running(){
	if [ -f "$LOCK_FILE" ]; then
		return 0 #true
	else
		return 1 #false
	fi
}

################################################################################
# Main program                                                                 #
################################################################################
main() {
	echo "Script version : $_VERSION"
	# Check the script is running or not
	if is_script_running; then
		echo "Previous script is still running.Stop processing!"
		return
	fi

	touch "$LOCK_FILE"
	for i in "${ROOT_PATH[@]}"; do
		echo "===> Zipbot start "
		echo "Working directory:" $i 
		zip_execute $i
		echo "<=== Zipbot finish. "
		echo
	done

	rm -rf "$LOCK_FILE"
	echo
	echo "=============="
	echo "Total folder zipped : " $((TOTAL_DIR - FALSE_DIR))
	echo "Total zip file size : " $(convert_size $TOTAL_ZIP_SIZE)
	echo "Corrupt file : " $INVALID_ZIP
	echo "Over threshold : " $OVER_THRESHOLD_COUNT
	echo "Under threshold : " $UNDER_THRESHOLD_COUNT
	echo "Bye!"
}

SUMMARY_LOG="$LOG_PATH/"$(date +%d%m%Y)".txt"
main | while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done | tee "$SUMMARY_LOG"
