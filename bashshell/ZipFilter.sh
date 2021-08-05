#!/bin/bash
###################################################################
#Script Name    : ZipFilter
#Description    : This script loop through all zip file in subfolder
#                 Find the biggest zip file size and copy to targer folder
#Version        : 1.8
#Notes          : None                                             
#Author         : phongtran0715@gmail.com
###################################################################
RED='\033[0;31m'
YELLOW='\033[1;33m'
GRAY='\033[1;30m'
NC='\033[0m'

# This folder contain the biggest zip files
# DEST_PATH="/mnt/restore/UPLOAD"

# This folder contain zip file that have size less than the biggest size
# DELETE_PATH="/mnt/restore/__DELBIG/"

# Max number zip file per output folder
# MAX_FILE=200

# This folder contain log file
LOG_PATH="/mnt/ajplus/Admin"

TOTAL_FILE_SMALLER=0
TOTAL_SIZE_SMALLER=0

TOTAL_FILE_BIGGEST=0
TOTAL_SIZE_BIGGEST=0

helpFunction()
{
  echo ""
  echo "Usage: $0 [option] folder_path"
  echo -e "Example : ./ZipFilter -c /home/jack/Video"
  echo -e "option:"
  echo -e "\t-c Check filter command"
  echo -e "\t-x Apply filter command"
  echo -e "\t-m Max number zip file per output folder"
  echo -e "\t-o Destination folder to store the biggest zip files"
  exit 1
}

while getopts "c:x:m:o:" opt
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
		  while [ "$OPTIND" -le "$#" ] && [ "${!OPTIND:0:1}" != "-" ]; do 
			INPUT+=("${!OPTIND}")
			OPTIND="$(expr $OPTIND \+ 1)"
		  done
		  mode="RUN";;
		m) MAX_FILE="$OPTARG" ;;
		o) DEST_PATH="$OPTARG" ;;
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

move_biggest_zip(){
	local file=$(realpath "$1")
	name=$(basename "$file")
	path=$(dirname "$file")
	size=$(get_file_size "$file")
	num_folder=$(find "$DEST_PATH" -maxdepth 1 -type d | tail -n +2 | wc -l)
	if [ $num_folder -eq 0 ];then
		dest_folder="$DEST_PATH/OUT"$num_folder"/"
	else
		# count number file at the latest folder
		index=$(($num_folder -1))
		latest_folder="$DEST_PATH/OUT"$index"/"
		nc=$(find "$latest_folder" -maxdepth 1 -type f | wc -l)
		if [ $nc -lt $MAX_FILE ];then
			dest_folder="$latest_folder"
		else
			dest_folder="$DEST_PATH/OUT"$num_folder"/"
		fi
	fi
	
	echo "Moving [$1] to [$dest_folder]"
	if [[ $mode == "RUN" ]];then
		mkdir -p "$dest_folder"
		mv -f "$file" "$dest_folder"
	fi
	echo "$name,$(convert_size $size),$path,Y,$path,$dest_folder" >> "$db_net"
}

remove_space(){
  local dir="$1"
  #  Loop throught all sub folder
  list_sub_dir=$(find "$dir" -type d | tail -n +2)
  while IFS= read -r sub_dir; do
	for old_name in "$sub_dir/"*; do
	  file_name=$(basename "$old_name")
	  new_name=`echo "$file_name" | sed -e 's/ //g'`
	  new_name=$(dirname "$old_name")/"$new_name"
	  mv -f "$old_name" "$new_name" 2>/dev/null
	done
  done < <(printf '%s\n' "$list_sub_dir")
}

main(){
	validate=0
	if [ -z "$MAX_FILE" ]; then
		MAX_FILE=200
	fi

	if [ "$OPTIND" -eq "1" ] || [ "$OPTIND" -le "$#" ]; then
	  helpFunction
	fi

	if [ ! -d "$DEST_PATH" ]; then printf "${RED}Error! Directory doesn't exist [DEST_PATH][$DEST_PATH]${NC}\n"; validate=1; fi
	if [ ! -d "$LOG_PATH" ]; then printf "${RED}Error! Directory doesn't exist [LOG_PATH][$LOG_PATH]${NC}\n"; validate=1; fi
	if [ $validate -eq 1 ];then return;fi

	db_net="$LOG_PATH/filter_zip.csv"
	echo "Name, Size, Path, IsBiggest, Source path, Move to" > "$db_net"
	# get list input directory
	list_dir=""
	num_sub_dirs=0
	for argument in "${INPUT[@]}"; do
	  remove_space "${argument}"
	  list_dir="${argument} $list_dir "
	  # count number sub folder
	  num_sub_dirs=$((num_sub_dirs + $(find ${argument} -type d | tail -n +2 | wc -l)))
	done
	
	# find all unique zip file name
	sum=1
	unique_names=$(find $list_dir -type f  -iname "*.zip" -printf "%f\n" | sort --unique)
	unique_names=($unique_names)
	for name in "${unique_names[@]}"; do
	  echo "($sum) Process file : $name"
	  sum=$((sum + 1))
	  # find all zip file by name
	  files=$(find $list_dir -type f -iname "$name" -printf "%s %p\n" | sort -rn | sed 's/^[0-9]* //')
	  # files=($files)
	  count=0
	  while IFS= read -r f; do
		if [ ! -z "$f" ];then
		  value=$(realpath "$f")
		  file_name=$(basename "$value")
		  path=$(dirname "$value")
		  size=$(get_file_size "$value")
		  if [ $count -eq 0 ];then 
			  isBiggest="Y"
			  move_biggest_zip "$f"
			  TOTAL_FILE_BIGGEST=$((TOTAL_FILE_BIGGEST + 1))
			  TOTAL_SIZE_BIGGEST=$((TOTAL_SIZE_BIGGEST + $size))
		  else
			  isBiggest="N"
			  # keep file in current diectory
			  TOTAL_FILE_SMALLER=$((TOTAL_FILE_SMALLER + 1))
			  TOTAL_SIZE_SMALLER=$((TOTAL_SIZE_SMALLER + $size))
			  echo "$file_name,$(convert_size $size),$path,$isBiggest,$(dirname "$value")" >> "$db_net"
		  fi
		  count=$((count+1))
		fi 
	  done < <(printf '%s\n' "$files")
	done

   echo 
   echo "===================="
   printf "%10s %-15s : ${#INPUT[@]}\n" "-" "Input folders"
   printf "%10s %-15s : $num_sub_dirs\n" "-" "Sub folders"
   printf "%10s %-15s : $((TOTAL_FILE_SMALLER + TOTAL_FILE_BIGGEST))\n" "-" "Processed file"
   TOTAL_SIZE=$((TOTAL_FILE_SMALLER + TOTAL_SIZE_BIGGEST))
   printf "%10s %-15s : %s\n" "-" "Processed size" "$(convert_size $TOTAL_SIZE)"
   echo
   printf "%10s %-15s : $TOTAL_FILE_SMALLER\n" "-" "Smaller files"
   printf "%10s %-15s : %s\n" "-" "Smaller size" "$(convert_size $TOTAL_SIZE_SMALLER)"
   echo
   printf "%10s %-15s : $TOTAL_FILE_BIGGEST\n" "-" "Biggest file"
   printf "%10s %-15s : %s\n" "-" "Biggest size" "$(convert_size $TOTAL_SIZE_BIGGEST)"
   echo
   printf "%10s %-15s : $log_file \n" "-" "Log file"
   printf "%10s %-15s : $db_net \n" "-" "Report"
   echo "===================="
   echo "Bye"
}

log_file="$LOG_PATH/filter_zip.txt"
main | while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done | tee "$log_file"