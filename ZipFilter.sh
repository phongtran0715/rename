#!/bin/bash
###################################################################
#Script Name    : ZipFilter
#Description    : This script loop through all zip file in subfolder
#                 Find the biggest zip file size and copy to targer folder
#Version        : 1.3
#Notes          : None                                             
#Author         : phongtran0715@gmail.com
###################################################################
RED='\033[0;31m'
YELLOW='\033[1;33m'
GRAY='\033[1;30m'
NC='\033[0m'

# This folder contain the biggest zip files
DEST_PATH="/mnt/restore/UPLOAD"

# This folder contain zip file that have size less than the biggest size
DELETE_PATH="/mnt/restore/__DELBIG/"

# This folder contain log file
LOG_PATH="/mnt/ajplus/Admin"

# Max number zip file per output folder
MAX_FILE=200

TOTAL_FILE_DELETE=0
TOTAL_SIZE_DELETE=0

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
  exit 1
}

while getopts "c:x:" opt
do
   case "$opt" in
      c ) INPUT="$OPTARG"
          mode="TEST";;
      x ) INPUT="$OPTARG"
          mode="RUN";;
      ? ) helpFunction ;;
   esac
done

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

main(){
    validate=0
    if [ ! -d "$DEST_PATH" ]; then printf "${RED}Error! Directory doesn't exist [DEST_PATH][$DEST_PATH]${NC}\n"; validate=1; fi
    if [ ! -d "$DELETE_PATH" ]; then printf "${RED}Error! Directory doesn't exist [DELETE_PATH][$DELETE_PATH]${NC}\n"; validate=1; fi
    if [ ! -d "$LOG_PATH" ]; then printf "${RED}Error! Directory doesn't exist [LOG_PATH][$LOG_PATH]${NC}\n"; validate=1; fi
    if [ $validate -eq 1 ];then return;fi

    echo "Working directory : $INPUT"
    db_net="$LOG_PATH/$(basename "$INPUT").csv"
    echo "Name, Size, Path, IsBiggest, Source path, Move to" > "$db_net"

    if [[ -d "$INPUT" ]]; then
        # count number sub folder
        num_sub_dirs=$(find "$INPUT" -maxdepth 1 -type d | tail -n +2 | wc -l)
        # find all unique zip file name
        unique_names=$(find "$INPUT" -type f  -iname "*.zip" -printf "%f\n" | sort --unique)
        while IFS= read -r name; do
            # find all zip file by name
            files=$(find "$INPUT" -type f -iname "$name" -printf "%s %p\n" | sort -rn| sed 's/^[0-9]* //')
            count=0
            while IFS= read -r f
            do
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
                        #move file to delete folder
                        echo "Moving [$f] to [$DELETE_PATH]"
                        if [[ $mode == "RUN" ]];then
                            mv -f  "$value" "$DELETE_PATH/"
                        fi
                        TOTAL_FILE_DELETE=$((TOTAL_FILE_DELETE + 1))
                        TOTAL_SIZE_DELETE=$((TOTAL_SIZE_DELETE + $size))
                        echo "$file_name,$(convert_size $size),$path,$isBiggest,$(dirname "$value"), $DELETE_PATH" >> "$db_net"
                    fi
                    count=$((count+1))
                fi
            done < <(printf '%s\n' "$files")
        done < <(printf '%s\n' "$unique_names")
   fi
   echo 
   echo "===================="
   printf "%10s %-15s : $num_sub_dirs\n" "-" "Total sub folders"
   printf "%10s %-15s : $((TOTAL_FILE_DELETE + TOTAL_FILE_BIGGEST))\n" "-" "Total processed file"
   TOTAL_SIZE=$((TOTAL_FILE_DELETE + TOTAL_SIZE_BIGGEST))
   printf "%10s %-15s : %s\n" "-" "Total processed size" "$(convert_size $TOTAL_SIZE)"
   printf "%10s %-15s : $log_file \n" "-" "Log file"
   printf "%10s %-15s : $db_net \n" "-" "Report"
   echo
   printf "%10s %-15s : $TOTAL_FILE_DELETE\n" "-" "Total deleted file"
   printf "%10s %-15s : %s\n" "-" "Total deleted size" "$(convert_size $TOTAL_SIZE_DELETE)"
   echo
   printf "%10s %-15s : $TOTAL_FILE_BIGGEST\n" "-" "Total biggest file"
   printf "%10s %-15s : %s\n" "-" "Total biggest size" "$(convert_size $TOTAL_SIZE_BIGGEST)"
   echo "===================="
   echo "Bye"
}

log_file="$LOG_PATH/$(basename "$INPUT").txt"
main | while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done | tee "$log_file"


