#!/bin/bash
###################################################################
#Script Name    : find_tags
#Description    : This script loop through all folder, find file 
# 					by tags name and create symlink to tags folder 
#Version        : 1.0
#Notes          : None                                             
#Author         : phongtran0715@gmail.com
###################################################################

# This folder contain tag list 
TAG_DIR="$HOME/tags/"

# The script will look up this folder to find plain text file
# filter file by tag and create symblink
SEARCH_DIR="$HOME/"

# This folder contain report (output log: index.txt) file
REPORT_DIR="$HOME/tags_report/"

update_report(){
	local input_file="$1"
	local tag="$2"

	report_file="$REPORT_DIR/$tag""_index.txt"
	tag_lines=$(grep "$tag" "$input_file")
	while IFS= read -r line; do
		echo "$input_file:$line" >> "$report_file"
	done < <(printf '%s\n' "$tag_lines")
}

main(){
	tag_count=0
	total_file_count=0
	text_file_count=0
	symblink_count=0
	validate=0
	# validate configuration
  	if [ ! -d "$TAG_DIR" ]; then printf "Error! Directory doesn't existed [TAG_DIR: $TAG_DIR]\n"; validate=1; fi
  	if [ ! -d "$SEARCH_DIR" ]; then printf "Error! Directory doesn't existed [SEARCH_DIR: $SEARCH_DIR]\n"; validate=1; fi
  	if [ $validate == 1 ]; then
  		return
  	fi
  	if [ ! -d "$REPORT_DIR" ]; then
  		mkdir -p "$REPORT_DIR/"
  	fi

	# Find all tags
	echo "Finding tags lits at : $TAG_DIR"
	tag_list=$(find "$TAG_DIR" -maxdepth 1  -type d -printf "%f\n" | tail -n +2)
	while IFS= read -r tag; do
		echo "($tag_count)Found tag : $tag"
		tag_count=$((tag_count+1))

		# initial report output file 
		report_output="$REPORT_DIR/$tag""_index.txt"
		if [ ! -f "$report_output" ]; then
			touch "$report_output"
		else
			echo "" > "$report_output"
		fi
	done < <(printf '%s\n' "$tag_list")

	# Find plain text files that contain tags
	echo "Finding plain text file at $SEARCH_DIR"
	file_list=$(find "$SEARCH_DIR" -type f -not -path "$TAG_DIR/*")
	while IFS= read -r file; do
		total_file_count=$((total_file_count+1))
		# find onlt ASCII text file
		if [[ $(file -0 "$file" | cut -d $'\0' -f2 | grep "text") ]];then
			text_file_count=$((text_file_count+1))
			echo "($text_file_count) : $file"
			# check file contain tag or not
			while IFS= read -r tag; do
				if [[ $(cat "$file" | grep "$tag") ]];then
					echo "Crated symblink with tag: $tag"
					#  create symblink
					if [[ "$mode" != "test" ]];then
						ln -s "$file" "$TAG_DIR/$tag/"
					fi
					update_report "$file" "$tag"
					symblink_count=$((symblink_count+1))
				fi
			done < <(printf '%s\n' "$tag_list")
		fi
	done < <(printf '%s\n' "$file_list")
	
	# show statistics
	echo
	echo "---------------------"
	echo "Number tags : " $tag_count
	echo "Total file : " $total_file_count
	echo "Number plain text file : " $text_file_count
	echo "Number symblink created : " $symblink_count
	echo "Report log: $REPORT_DIR"
	echo "Bye!"
}

mode="$1"
if [ -z "$mode" ];then mode="execute";fi
echo "Run mode : $mode"

main