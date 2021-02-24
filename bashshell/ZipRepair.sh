#!/bin/bash
###################################################################
#Script Name    : ZipRepair
#Description    : This script loop through all zip file in subfolder
#                 Find the corrupt zip file and repair automatically
#Version        : 1.0
#Notes          : None
#Author         : phongtran0715@gmail.com
###################################################################

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# This folder contain log file
LOG_PATH="/mnt/ajplus/Admin"
INVALID_SIZE=0
REPAIRED_SIZE=0

helpFunction() {
  echo ""
  echo "Usage: $0 [option] folder_path [option] language"
  echo -e "Example : ./ZipRepair -c /folder1 /folder2 ..."
  echo -e "option:"
  echo -e "\t-c Check corrupt zip file"
  echo -e "\t-x Repair corrupt zip file"
  exit 1
}

while getopts "c:x:" opt; do
  case "$opt" in
  c)
    INPUT+=("$OPTARG")
    while [ "$OPTIND" -le "$#" ] && [ "${!OPTIND:0:1}" != "-" ]; do
      INPUT+=("${!OPTIND}")
      OPTIND="$(expr $OPTIND \+ 1)"
    done
    mode="TEST"
    ;;
  x)
    INPUT+=("$OPTARG")
    mode="RUN"
    ;;
  ?) helpFunction ;;
  esac
done
shift $((OPTIND - 1))

convert_size() {
  printf %s\\n $1 | LC_NUMERIC=en_US numfmt --to=iec
}

get_file_size() {
  echo $(stat -c%s "$1")
}

validate_zip() {
  # check zipfile integrity
  local file_path="$1"
  result=$(zip -T "$file_path" | rev | cut -d ' ' -f 1 | rev) >/dev/null
  echo "$result"
}

repair_zip() {
  local file_path="$1"
  file_name=$(basename "$file_path")
  ext=$(echo $file_name | cut -d '.' -f2-)
  name=$(echo $file_name | cut -d '.' -f 1)
  out_file="$(dirname "$file_path")/$name-TMPABC.$ext"
  zip -F "$file_path" --out "$out_file" >/dev/null
  status=$?
  if [[ "$status" == "0" ]]; then
    # remove original zip file
    rm -rf "$file_path"
    # rename repaied zip file
    mv "$out_file" "$file_path"
  fi
  echo "$status"
}

main() {
  validate=0
  total=0
  invalid_count=0
  repair_count=0
  if [ "$OPTIND" -eq "1" ] || [ "$OPTIND" -le "$#" ]; then
    helpFunction
  fi
  if [ ! -d "$LOG_PATH" ]; then
    printf "${RED}Error! Directory doesn't exist [LOG_PATH][$LOG_PATH]${NC}\n"
    validate=1
  fi
  if [ $validate -eq 1 ]; then return; fi

  # get list input directory
  list_dir=""
  for argument in "${INPUT[@]}"; do
    list_dir="${argument} $list_dir "
  done

  echo "Input directory : $list_dir"
  echo
  # find all zip file
  zip_files=$(find $list_dir -type f -iname "*.zip")
  while IFS= read -r file; do
    if [ ! -f "$file" ]; then continue; fi
    total=$((total + 1))
    size=$(get_file_size "$file")
    echo "----------"
    echo "($total)Cheking file ($(convert_size $size)): $file"
    is_valid=$(validate_zip "$file")
    if [[ "$is_valid" == "OK" ]]; then
      printf "${GREEN}OK!${NC}\n"
    else
      INVALID_SIZE=$((INVALID_SIZE + $size))
      printf "${RED}Invalid!!!${NC}\n"
      invalid_count=$((invalid_count + 1))
      if [[ $mode == "RUN" ]]; then
        echo "Repairing ..."
        status=$(repair_zip "$file")
        if [[ "$status" == "0" ]]; then
          repair_count=$((repair_count + 1))
          echo "Repaired"
          REPAIRED_SIZE=$((REPAIRED_SIZE + $size))
        else
          echo "Can NOT repair file : $file"
        fi
      fi
    fi
    echo "----------"
    echo
  done < <(printf '%s\n' "$zip_files")
  echo
  echo "===================="
  printf "%10s %-15s : $total\n" "-" "Total files"
  printf "%10s %-15s : $invalid_count\n" "-" "Invalid files"
  printf "%10s %-15s : $(convert_size $INVALID_SIZE)\n" "-" "Invalid size"
  printf "%10s %-15s : $repair_count\n" "-" "Repaired files"
  printf "%10s %-15s : $(convert_size $REPAIRED_SIZE)\n" "-" "Repaired size"
  echo bye
}
log_file="$LOG_PATH/repair_zip.txt"
main | while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done | tee "$log_file"
