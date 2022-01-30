#!/bin/bash
###################################################################
#Script Name    : SpiltFolder
#Description    : Split parent folers based on folder zise and zip child folders
#Version        : 1.0
#Notes          : None
#Author         : phongtran0715@gmail.com
###################################################################

_VERSION="SplitFolder - 1.0"

# Log folder store application running log, report log
LOG_PATH="/mnt/ajplus/Admin/"

#  Report files
REPORT_FILE="$LOG_PATH/matched_video_report_"$(date +%d%m%y_%H%M)".csv"
NEW_VIDEO_NAME_FILE="$LOG_PATH/new_video_name_"$(date +%d%m%y_%H%M)".txt"


TOTAL_SUB_FOLDER=0
DIVIDE_BASE_SIZE=1g #1G

OUTPUT_PATH="/mnt/restore/ZIP_FOLDER/"

function DEBUG() {
  [ "$_DEBUG" == "dbg" ] && $@ || :
}

convert_size() {
  printf %s\\n $1 | LC_NUMERIC=en_US numfmt --to=iec
}

helpFunction() {
  echo ""
  echo "Script version : $_VERSION"
  echo "Usage: $0  input_folder"
  echo -e "Example : ./SplitFolder.sh /mnt/restore/VIDEO/"
  exit 1
}

main(){
	INPUT=$1
	echo "Script version : $_VERSION"
	if [[ -d "$INPUT" ]]; then
		echo "Input folder : [$INPUT]"
	else
		echo "Error! Input folder is invalid"
		helpFunction
		return
	fi

	sub_dirs=$(find "$INPUT" -maxdepth 1 -type d | tail -n +2)
	while IFS= read -r dir; do
		echo "*** Processing sub folder ($(du -sh $dir | awk '{printf $1}')): $dir"
		TOTAL_SUB_FOLDER=$(($TOTAL_SUB_FOLDER + 1))
		# remove space from dir name
		folder_name=$(echo $(basename $dir) | tr -d ' ')
		# create output foler
		mkdir -p "$OUTPUT_PATH"$folder_name 


		output_folder="$OUTPUT_PATH$folder_name/"
		zip_file="$dir/$folder_name".zip
		zip -r $zip_file "$dir" >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "Zip folder successfully"
			# split zip file to multiple parts
			zip $zip_file --out $output_folder$folder_name".zip" -s $DIVIDE_BASE_SIZE >/dev/null 2>&1
			num_child_zip=$(find $output_folder -maxdepth 1 -type f -iname "*.z*" | wc -l)
			output_file=$output_folder"README.txt"

			echo "The master Adobe folder has been divided into $num_child_zip folders due to zip size" >> $output_file
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
		else
			echo "Error! There is an unexpected error when zipping : "$dir
		fi
	done < <(printf '%s\n' "$sub_dirs")
	echo "===================="
	printf "%10s %-15s : $TOTAL_SUB_FOLDER\n" "-" "Total child folders"
	printf "%10s %-15s : $log_file \n" "-" "Log file"
	echo "===================="
	echo "Bye"
}

log_file="$LOG_PATH/split_folder_log_"$(date +%d%m%y_%H%M)".txt"

main $1 | while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done | tee "$log_file"

echo "Bye"

