#!/bin/bash

RED='\033[0;31m'
YELLOW='\033[1;33m'
GRAY='\033[1;30m'
NC='\033[0m'

# Root directory needed to run zip command
ROOT_PATH=(
    "/mnt/ajplus/Pipeline/_ARCHIVE_INDVCMS/"
    )

# Directory hold unsuccesful zip folder
FAIL_PATH="/mnt/ajplus/Admin/CMS/zipX/Failed/"

# Directory hold zip file that have file size >= Threshold
OVER_THRESHOLD_PATH="/mnt/cms/Upload_To_DMV_2/"

# Directory hold zip file that have file size < Threshold
UNDER_THRESHOLD_PATH="/mnt/ajplus/_OUT_Box/Upload_To_DMV/"

# Log file directory
LOG_PATH="/mnt/ajplus/Admin/CMS/zipX/Logs/"

# Directory hold all zipped file
ARCHIVE_PATH="/mnt/ajplus/_OUT_Box/Zip_7day_Archive/"

# Directory hold over folder size
PARK="/mnt/ajplus/_OUT_Box/PARK/"

FILE_SIZE_THRESHOLD=$((100 *1024 *1024 *1024)) #Threshold 100G

FOLDER_SIZE_THRESHOLD=$((2304 *1024 *1024 *1024)) #Threshold 2.25TB

convert_size(){
  printf %s\\n $1 | LC_NUMERIC=en_US numfmt --to=iec
}

delete_folder() {
  local folder="$1"
  local log_file="$2"
  echo "========== DELETE INFO START ==========" >> "$log_file"
  echo "["$(date +"%m-%d-%Y %T %Z")"] Start delete " >> "$log_file"
  echo "["$(date +"%m-%d-%Y %T %Z")"] Deleting folder [$folder]" | tee -a "$log_file"
  rm -rf "$folder"
  echo "["$(date +"%m-%d-%Y %T %Z")"] Finish delete" >> "$log_file"
  echo "========== DELETE INFO END ==========" >> "$log_file"
  echo  >> "$2"
}

move_zip_file(){
  local src_file="$1"
  local dest_folder="$2"
  local log_file="$3"
  echo "========== ZIP FILE MOVEMENT START ==========" >> "$log_file"
  echo "["$(date +"%m-%d-%Y %T %Z")"] Copying zip file to : ["$ARCHIVE_PATH"]" | tee -a "$log_file"
  echo
  file_name=$(basename "$src_file")
  # pv "$src_file" > "$ARCHIVE_PATH/$file_name"
  cp -f "$src_file" "$ARCHIVE_PATH/$file_name"
  echo "["$(date +"%m-%d-%Y %T %Z")"] Moving zip file to : [$dest_folder]" | tee -a "$log_file"
  mv -f "$src_file" "$dest_folder/$file_name"
  # pv "$src_file" > "$dest_folder/$file_name"
  # rm -rf "$src_file"
  echo "========== ZIP FILE MOVEMENT END ==========" >> "$log_file"
  echo >> "$log_file"
}

move_fail_folder(){
  local src_folder="$1"
  local dest_folder="$2"
  local log_file="$3"
  echo "========== ZIP FILE MOVEMENT START ==========" >> "$log_file"
  echo "Failed zip folder : $src_folder"  | tee -a "$log_file"
  echo "["$(date +"%m-%d-%Y %T %Z")"] Moving zip folder to : [$dest_folder]" | tee -a "$log_file"
  mv -f "$src_folder" "$dest_folder"
  echo "========== ZIP FILE MOVEMENT END ==========" >> "$log_file"
  echo >> "$log_file"  
}

get_info_hierarchy() {
  local folder="$1"
  local log_file="$2"
  echo "========== FOLDER HIERARCHY INFO START ==========" >> "$log_file"
  tree --du -lah "$folder" >> "$log_file"
  echo "========== FOLDER HIERARCHY INFO END ==========" >> "$log_file"
  echo >> "$log_file"
}

TOTAL_DIR=0
FALSE_DIR=0
TOTAL_ZIP_SIZE=0
zip_execute() {
  if [ ! -d "$1" ]; then
      echo "Directory " $1 "DOES NOT exists."
      return
  fi
  # TODO : check folder size
  folder_size=$(du -s "$1" | awk '{printf $1}')
  if [ $folder_size -gt $FOLDER_SIZE_THRESHOLD ];then
    echo "Folder size $(convert_size $folder_size) is over threshold $(convert_size $FOLDER_SIZE_THRESHOLD)"
    echo "Moving folder to [$PARK]"
    mv -rf "$1" "$PARK"
    return
  fi
  
  cd "$1"
  for dir in $1*; do
      if [ -d "$dir" ]; then
        TOTAL_DIR=$((TOTAL_DIR+1))
        DIR_NAME=$(basename "$dir")
        # remove space from dir name
        STANDARD_DIR_NAME=$(echo $DIR_NAME | tr -d ' ')
        ZIP_FILE="$STANDARD_DIR_NAME".zip
        LOG_FILE="$LOG_PATH$STANDARD_DIR_NAME".txt
        echo "" > "$LOG_FILE"            
        get_info_hierarchy "$dir" "$LOG_FILE"
        echo "========== COMPRESS INFO START ==========" >> "$LOG_FILE"
        echo "["$(date +"%m-%d-%Y %T %Z")"] Zipping Folder : $dir" | tee -a "$LOG_FILE"
        echo "["$(date +"%m-%d-%Y %T %Z")"] Start compress" >> "$LOG_FILE"
        # zip -qr - "$DIR_NAME" | pv > "$ZIP_FILE"
        zip -r $ZIP_FILE "$DIR_NAME" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
          FILE_SIZE=$(stat -c%s "$ZIP_FILE")
          echo "["$(date +"%m-%d-%Y %T %Z")"] Zipped file ($(convert_size $FILE_SIZE)): $ZIP_FILE " | tee -a "$LOG_FILE"
          echo
          echo "["$(date +"%m-%d-%Y %T %Z")"] Finish compress" >> "$LOG_FILE"
          echo "========== COMPRESS INFO END ==========" >> "$LOG_FILE"
          echo >> "$LOG_FILE"              
          echo "$dir, $STANDARD_DIR_NAME".zip, " $(convert_size $FILE_SIZE)" >> "$SUMMARY_LOG"
          TOTAL_ZIP_SIZE=$(($TOTAL_ZIP_SIZE + $FILE_SIZE))
          if [ $FILE_SIZE -ge $FILE_SIZE_THRESHOLD ]; then
            move_zip_file "$ZIP_FILE" "$OVER_THRESHOLD_PATH" "$LOG_FILE"
          else
            move_zip_file "$ZIP_FILE" "$UNDER_THRESHOLD_PATH" "$LOG_FILE"
          fi
          echo
          delete_folder "$dir" "$LOG_FILE"
          echo
          echo "Log file : $LOG_FILE"
        else
          echo "========== COMPRESS INFO END ==========" >> "$LOG_FILE"
          move_fail_folder "$dir" "$FAIL_PATH" "$LOG_FILE"
          echo "$dir, [FAILED]" >> "$SUMMARY_LOG"
          FALSE_COUNT=$((FALSE_COUNT+1))
        fi
      fi
  done
}

#################################################################################
# Validate input argument                                                      #
################################################################################
validate=0
# if [ ! -d "$ROOT_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [ROOT_PATH][$ROOT_PATH]${NC}\n"; validate=1; fi
if [ ! -d "$FAIL_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [FAIL_PATH][$FAIL_PATH]${NC}\n"; validate=1; fi
if [ ! -d "$OVER_THRESHOLD_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [OVER_THRESHOLD_PATH][$OVER_THRESHOLD_PATH]${NC}\n"; validate=1; fi
if [ ! -d "$UNDER_THRESHOLD_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [UNDER_THRESHOLD_PATH][$UNDER_THRESHOLD_PATH]${NC}\n"; validate=1; fi
if [ ! -d "$ARCHIVE_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [ARCHIVE_PATH][$ARCHIVE_PATH]${NC}\n"; validate=1; fi
if [ ! -d "$PARK" ]; then printf "${YELLOW}Warning! Directory doesn't existed [PARK][$PARK]${NC}\n"; validate=1; fi
if [ ! -d "$LOG_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [LOG_PATH][$LOG_PATH]${NC}\n"; validate=1; fi

################################################################################
# Main program                                                                 #
################################################################################
SUMMARY_LOG="$LOG_PATH"$(date +%d%m%Y)".txt"
echo "===>" > "$SUMMARY_LOG"
for i in "${ROOT_PATH[@]}"
do
   echo "===> Zipbot start working on directory : " $i
   zip_execute $i
   echo "<=== Zipbot finish directory : " $i
   echo
done
echo >> "$SUMMARY_LOG"
echo "Total folder zipped : " $((TOTAL_DIR-FALSE_DIR)) >> "$SUMMARY_LOG"
echo "Total zip file size : " $(convert_size $TOTAL_ZIP_SIZE) >> "$SUMMARY_LOG"
echo "<===" >> "$SUMMARY_LOG"

echo "Bye"
