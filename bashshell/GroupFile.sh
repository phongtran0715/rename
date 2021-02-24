#!/bin/bash
###################################################################
#Script Name    : GroupFile
#Description    : This script wil create folder base on zip file name
#               : Move zip , movie with matched name to folder
#Version        : 1.0
#Notes          : None
#Author         : phongtran0715@gmail.com
###################################################################
helpFunction() {
  echo ""
  echo "Usage: $0 folder_path "
  echo -e "Example : ./GroupFile.sh /home/jack/Video"
  exit 1
}

while getopts "h:" opt; do
  case "$opt" in
  ?) helpFunction ;;
  esac
done

main() {
  local input_path="$1"
  count=0
  if [ ! -d "$input_path" ]; then
    printf "Warning! Directory doesn't existed [$input_path]\n"
    return
  fi
  # get all zip file in this directory
  files=$(ls -S "$input_path" | egrep '\.zip$|\.Zip$|\.ZIP$')
  while read file_name; do
    if [ -z "$file_name" ]; then continue; fi
    name_no_ext=$(echo $file_name | cut -f 1 -d '.')
    path="$input_path/$name_no_ext"
    # create folder
    mkdir -p "$path"
    echo "Created folder [$path]"
    # move file to folder
    mv -f "$path"* "$path/" >/dev/null 2>&1
    count=$((count + 1))
  done <<<"$files"
  echo "$count folder was created"
}

if [ -z "$1" ]; then
  echo "Error! Missing input directory"
  helpFunction
fi
main "$1" | while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done
