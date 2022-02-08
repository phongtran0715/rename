#!/bin/bash
###################################################################
#Script Name    : SpiltFolder
#Description    : Split parent folers based on folder zise and zip child folders
#Version        : 1.2
#Notes          : None
#Author         : phongtran0715@gmail.com
###################################################################

_VERSION="SplitFolder - 1.2"

# Root directory needed to run zip command
# ROOT_PATH=(
# 	"/mnt/ajplus/Pipeline/_ARCHIVE_INDVCMS/ajplus"
# )

ROOT_PATH=(
	"/home/jack/Downloads/Document/EBOOK"
)

# Directory hold unsuccesful zip folder
FAIL_PATH="/mnt/ajplus/Admin/CMS/zipX/Failed/"

# Directory hold all input folders
ARCHIVE_PATH="/mnt/ajplus/_OUT_Box/Zip_7day_Archive/"

# Log folder store application running log, report log
LOG_PATH="/mnt/ajplus/Admin/"

# deleted folder size threshold value (equivalent to bytes)
# input folder with size smaller than the threshold will be deleted
FOLDER_SIZE_THRESHOLD=$((50 * 1024 * 1024)) #50Mb

# folder stores output zip file
OUTPUT_PATH="/mnt/ajplus/_OUT_Box/Upload_To_DMV/"

#This folder stores all folders that have size small than threshold size
DELETED_DIR="/mnt/restore/__DEL/"

TOTAL_FOLDER=0
TOTAL_PROCESSED_FOLDER=0
TOTAL_FAILED_FOLDER=0
TOTAL_IGNORED_FOLDER=0

# A large zip file will be splited to multiple part by each DIVIDE_BASE_SIZE
# Example : 100m (100 megabyte) or 1g (1 gigabyte)
DIVIDE_BASE_SIZE=100m #1G

function DEBUG() {
  [ "$_DEBUG" == "dbg" ] && $@ || :
}

helpFunction() {
  echo ""
  echo "Script version : $_VERSION"
  echo "Usage: $0"
  echo -e "Example : ./SplitFolder.sh"
  exit 1
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

  if [ ! -d "$ARCHIVE_PATH" ]; then
    printf "Warning! Directory doesn't existed [ARCHIVE_PATH][$ARCHIVE_PATH]\n"
    validate=1
  fi

  if [ ! -d "$LOG_PATH" ]; then
    printf "Warning! Directory doesn't existed [LOG_PATH][$LOG_PATH]\n"
    validate=1
  fi

  if [ ! -d "$OUTPUT_PATH" ]; then
    printf "Warning! Directory doesn't existed [OUTPUT_PATH][$OUTPUT_PATH]\n"
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

	sub_dirs=$(find "$ROOT_PATH" -maxdepth 1 -type d | tail -n +2)
	echo "folder threshold:"$FOLDER_SIZE_THRESHOLD
	while IFS= read -r dir; do
		TOTAL_FOLDER=$(($TOTAL_FOLDER + 1))
		echo
		echo "*** Processing sub folder ($(du -sh $dir | awk '{printf $1}')): $dir"
		folder_size=$(du -sb $dir | awk '{printf $1}')
		if [ $folder_size -lt $FOLDER_SIZE_THRESHOLD ]; then
			echo "Folder size is smaller then threshold. Ignore!"
			TOTAL_IGNORED_FOLDER=$(($TOTAL_IGNORED_FOLDER + 1))
			echo "Moving the directory to deleted path"
			cp -rf "$dir" "$DELETED_DIR"
			rm -rf "$dir"
			continue
		fi
		# remove space from dir name
		folder_name=$(echo $(basename $dir) | tr -d ' ')
		# create output foler
		mkdir -p "$OUTPUT_PATH"$folder_name 

		output_folder="$OUTPUT_PATH$folder_name/"
		zip_file="$dir/$folder_name".zip
		cd "$dir"
		zip -r $zip_file ../ >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			TOTAL_PROCESSED_FOLDER=$(($TOTAL_PROCESSED_FOLDER + 1))
			echo "Zip folder successfully"
			# split zip file to multiple parts
			zip $zip_file --out $output_folder$folder_name".zip" -s $DIVIDE_BASE_SIZE >/dev/null 2>&1
			num_child_zip=$(find $output_folder -maxdepth 1 -type f -iname "*.z*" | wc -l)
			output_file=$output_folder"README.txt"

			echo "The master Adobe folder has been divided into $num_child_zip folders due to zip size" > $output_file
			echo "" >> $output_file
			output_files=$(find $output_folder -maxdepth 1 -type f -iname "*.z*")
			while IFS= read -r file; do
				echo $file >> $output_file
			done < <(printf '%s\n' "$output_files")
			echo "" >> $output_file
			echo "Please download all zip files and merge them by below command:" >> $output_file
			echo "cat $folder_name.z* > $folder_name""_final.zip" >> $output_file
			# delete original zip
			rm -rf $zip_file
			# move original folder to archive folder
			echo "Moving the directory to archive path"
			cp -rf "$dir" "$ARCHIVE_PATH" 
			rm -rf "$dir"
		else
			TOTAL_FAILED_FOLDER=$(($TOTAL_FAILED_FOLDER + 1))
			echo "Error! There is an unexpected error when zipping : "$dir
			echo "Moving the directory to failed path"
			cp -rf "$dir" "$FAIL_PATH"
			rm -f "$dir"

		fi
	done < <(printf '%s\n' "$sub_dirs")
	echo "===================="
	printf "%10s %-20s : $TOTAL_FOLDER\n" "-" "Total folders"
	printf "%10s %-20s : $TOTAL_PROCESSED_FOLDER\n" "-" "Processed folders"
	printf "%10s %-20s : $TOTAL_FAILED_FOLDER\n" "-" "Failed folders"
	printf "%10s %-20s : $TOTAL_IGNORED_FOLDER\n" "-" "Ignored folders"
	echo
	printf "%10s %-20s : $log_file \n" "-" "Log file"
	echo "===================="
	echo "Bye"
}

log_file="$LOG_PATH/split_folder_log_"$(date +%d%m%y_%H%M)".txt"

main $1 | while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done | tee "$log_file"

echo "Bye"

