#!/bin/bash
###################################################################
#Script Name    : MatchingVideo
#Description    : Find all video file that matched with zip file name in DB
#				Move video file to destination folder 
#Version        : 1.1
#Notes          : None                                             
#Author         : phongtran0715@gmail.com
###################################################################

SCRIPT_NAME=$1

# Log color code
RED='\033[0;31m'
YELLOW='\033[1;33m'
GRAY='\033[1;30m'
NC='\033[0m'

# check matching result code
NOT_MATCH=0
MATCH_OLD_NAME=1
MATCH_NEW_NAME=2

# Database file contain processed zip file name
DATABASE_FILE="/home/jack/Documents/SourceCode/rename_script/db/ar_db.csv"

# Log folder store application running log, report log
LOG_PATH="/home/jack/Documents/rename_test/log/"

# Folder store mp4 video
MP4_PATH="/home/jack/Documents/rename_test/mp4/"

# Folder sotre mov and mxf video file
MOV_MXF_PATH="/home/jack/Documents/rename_test/mxf/"

# Folder store file that doesn't match any name
OTHER_PATH="/home/jack/Documents/rename_test/other/"

#  Report file
REPORT_FILE="$LOG_PATH/matched_video_report.csv"

helpFunction()
{
  echo ""
  echo "Usage: $0 [option] folder_path [option] language"
  echo -e "Example : ./MatchVideo.sh -c /folder1 /folder2 ..."
  echo -e "option:"
  echo -e "\t-c Check corrupt zip file"
  echo -e "\t-x Repair corrupt zip file"
  exit 1
}

while getopts "c:x:" opt
do
    case "$opt" in
      c ) 
          INPUT+=("$OPTARG")
          while [ "$OPTIND" -le "$#" ] && [ "${!OPTIND:0:1}" != "-" ]; do 
            INPUT+=("${!OPTIND}")
            OPTIND="$(expr $OPTIND \+ 1)"
          done
          mode="TEST";;
      x ) INPUT+=("$OPTARG")
          mode="RUN";;
      ? ) helpFunction ;;
   esac
done
shift $((OPTIND -1))

convert_size(){
	printf %s\\n $1 | LC_NUMERIC=en_US numfmt --to=iec
}

get_file_size(){
	echo $(stat -c%s "$1")
}

get_target_folder_by_ext(){
	local file="$1"
	file_ext=$(echo "$file" | cut -d'.' -f2)
	if [[ $file_ext == "mp4" ]];then result="$MP4_PATH";
	elif [[ $file_ext == "mov" ]];then result="$MOV_MXF_PATH";
	elif [[ $file_ext == "mxf" ]];then result="$MOV_MXF_PATH";
	else result="$OTHER_PATH";fi
	echo $result
}

check_matching(){
	local movie_path="$1"
	movie_file=$(basename "$movie_path")
	movie_name=$(echo "$movie_file" | cut -d'.' -f1)
	
	# compare with old name
	old_match=$(awk -F "," '{print $1}' "$DATABASE_FILE" | grep "$movie_name")
	if [ ! -z "$old_match" ];then
		return $MATCH_OLD_NAME
	fi

	# compare with new name
	new_match=$(awk -F "," '{print $2}' "$DATABASE_FILE" | grep "$movie_name")
	if [ ! -z "$new_match" ];then
		return $MATCH_NEW_NAME
	fi

	return $NOT_MATCH
}

get_new_name(){
	local file="$1"
	#  get name without extension
	old_name=$(echo "$file" | cut -d'.' -f1)
	# get matched line, max count 1 line
	matched_line=$(grep -m1 "$old_name" "$DATABASE_FILE")
	new_name=$(awk -F "," '{print $2}' "$matched_line")
	return $new_name
}

main(){
	total=0
	matched_count=0
	matched_size=0
	
	# validate argument
	validate=0
	if [ ! -d "$MP4_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [MP4_PATH][$MP4_PATH]${NC}\n"; validate=1; fi
	if [ ! -d "$MOV_MXF_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [MOV_MXF_PATH][$MOV_MXF_PATH]${NC}\n"; validate=1; fi
	if [ ! -d "$OTHER_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [OTHER_PATH][$OTHER_PATH]${NC}\n"; validate=1; fi
	if [ ! -d "$LOG_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [LOG_PATH][$LOG_PATH]${NC}\n"; validate=1; fi

	if [ -f "$REPORT_FILE" ];then
    	rm -rf "$REPORT_FILE"
	fi
	touch "$REPORT_FILE"
	echo "Old Name, New Name, Size, Move to" > "$REPORT_FILE"
	
	# Collect all input folder
	list_dir=""
	for argument in "${INPUT[@]}"; do
		list_dir="${argument} $list_dir "
	done

    echo "List input directory : $list_dir"
    echo "Database file : $DATABASE_FILE"
    echo "-------------------------------"
    echo "Finding video in folder ..."
	video_files=$(find $list_dir -type f \( -iname \*.mov -o -iname \*.mxf -o -iname \*.mp4 \))
	while IFS= read -r file; do
		if [ ! -f "$file" ];then continue;fi
		total=$((total + 1))
		size=$(get_file_size "$file")
		echo "-------------------------------"
		echo "($total)Cheking file ($(convert_size $size)): $file"
		match_result=$(check_matching "$file")
		if [[ $match_result == $MATCH_OLD_NAME ]];then
			echo "Matched old name in DB."
			matched_count=$((matched_count + 1))
			matched_size=$((matched_size + $size))
			# rename file, get new name from DB
			new_name=$(get_new_name "$file")
			echo "Rename file to [$new_name]"
			if [[ $mode == "RUN" ]];then
				mv "$file" "$(basename "$file")/$new_name"
				file="$(basename "$file")/$new_name"
			fi
			target_folder=$(get_target_folder "$file")
			echo "Move file to [$target_folder]"
			if [[ $mode == "RUN" ]];then
				mv "$file" "$target_folder/"
			fi
			echo "$(basename "$file"), $new_name, $(convert_size $size), $target_folder" >> "$REPORT_FILE"
		elif [[ $match_result == $MATCH_NEW_NAME ]];then
			matched_count=$((matched_count + 1))
			matched_size=$((matched_size + $size))

			# move file to target folder
			target_folder=$(get_target_folder "$file")
			echo "Move file to [$target_folder]"
			if [[ $mode == "RUN" ]];then
				mv "$file" "$target_folder/"
			fi
			echo "$(basename "$file"), $(basename "$file"), $(convert_size $size), $target_folder" >> "$REPORT_FILE"
		else
			# move file to target folder
			echo "Not matched name"
			echo "Move file to [$OTHER_PATH]"
			if [[ $mode == "RUN" ]];then
				mv "$file" "$OTHER_PATH"
			fi
			echo "$(basename "$file"), , $(convert_size $size), $OTHER_PATH" >> "$REPORT_FILE"
		fi
		sleep 0.1
	done < <(printf '%s\n' "$video_files")
	echo
	echo "===================="
   	printf "%10s %-15s : $total\n" "-" "Total files"
   	printf "%10s %-15s : $matched_count\n" "-" "Matched files"
   	printf "%10s %-15s : $(convert_size $matched_size)\n" "-" "Matched size"
   	
   	printf "%10s %-15s : $log_file \n" "-" "Log file"
   	printf "%10s %-15s : $REPORT_FILE \n" "-" "Report file"
   	echo "Bye"
}
log_file="$LOG_PATH/matching_video_log.txt"

cpulimit -l 1 bash $SCRIPT_NAME
main | while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done | tee "$log_file"