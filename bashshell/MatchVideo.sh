#!/bin/bash
###################################################################
#Script Name    : MatchingVideo
#Description    : Finad all video in source folder, rename file (same ZipSun rule)
#               moce file to target folder 
#               Rename and move file to destination folder 
#Version        : 1.4
#Notes          : None                                             
#Author         : phongtran0715@gmail.com
###################################################################

# Log color code
RED='\033[0;31m'
YELLOW='\033[1;33m'
GRAY='\033[1;30m'
NC='\033[0m'

# check matching result code
NOT_MATCH=0
MATCH_OLD_NAME=1
MATCH_NEW_NAME=2

# This is file contain all country code
COUNTRY_FILE="countries.txt"

#List support language
LANGUAGES=("AR" "EN" "FR" "ES")

# List teams inside zip file name
TEAMS=("RT", "NG" "EG" "CT" "SH" "ST")

# Neglects keyword will be remove from zip file name
NEGLECTS_KEYWORD=("V1" "V2" "V3" "V4" "SQ" "-SW-" "-NA-" "FYT" "FTY" "SHORT" "SQUARE" "SAKHR"
  "KHEIRA" "TAREK" "TABISH" "ZACH" "SUMMAQAH" "HAMAMOU" "ITANI" "YOMNA" "COPY" "COPIED")

# List suffix keyword in video file name
SUFFIX_LISTS=("SUB" "FINAL" "YT" "CLEAN" "TW" "TWITTER" "FB" "FACEBOOK" "YT" "YOUTUBE" "IG" "INSTAGRAM")

# Log folder store application running log, report log
# LOG_PATH="/mnt/log/"
LOG_PATH="/home/jack/Documents/SourceCode/rename_script/log/"

DELETED_PATH="/home/jack/Documents/SourceCode/rename_script/log/del"

# Folder store mp4 video
# MP4_PATH="/mnt/log/mp4/"
MP4_PATH="/home/jack/Documents/SourceCode/rename_script/log/mp4/"

# Folder sotre mov and mxf video file
# MOV_MXF_PATH="/mnt/log/mxf/"
MOV_MXF_PATH="/home/jack/Documents/SourceCode/rename_script/log/mxf/"

# Folder store file that doesn't match any name
# OTHER_PATH="/mnt/log/other/"
OTHER_PATH="/home/jack/Documents/SourceCode/rename_script/log/other/"

#  Report file
REPORT_FILE="$LOG_PATH/matched_video_report.csv"

gline_path="/tmp/.line_"$(date +%s)
gteam_path="/tmp/.team_"$(date +%s)
gsuffix_path="/tmp/.suffix"$(date +%s)

helpFunction()
{
  echo ""
  echo "Usage: $0 [option] folder_path [option] language"
  echo -e "Example : ./MatchVideo.sh -c /folder1 /folder2 ..."
  echo -e "option:"
  echo -e "\t-c Check corrupt zip file"
  echo -e "\t-x Repair corrupt zip file"
  echo -e "\t-d Manual test with input text file"
  echo -e "\t-l Set language for file name"
  exit 1
}

while getopts "d:c:x:l:" opt
do
    case "$opt" in
        d ) INPUT="$OPTARG"
            mode="DUMMY";;
        c ) 
            INPUT+=("$OPTARG")
            while [ "$OPTIND" -le "$#" ] && [ "${!OPTIND:0:1}" != "-" ]; do 
                INPUT+=("${!OPTIND}")
            OPTIND="$(expr $OPTIND \+ 1)"
            done
            mode="TEST";;
        x ) INPUT+=("$OPTARG")
            mode="RUN";;
        l ) default_lang="$OPTARG";;
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

is_suffix(){
  local data="$1"
  for i in "${!SUFFIX_LISTS[@]}";do
    if [[ "$data" == "${SUFFIX_LISTS[$i]}" ]];then
      return 0 #true
    fi
  done
  return 1 #false
}

check_position_replace(){
  local name="$1"
  local search_str="$2"
  local replace_str="$3"
  shift
  result=$(echo $name | grep -b -o $search_str)
  if [ $? -eq 0 ]
  then
    index=$(echo $result | cut -f1 -d":")
    if [ $index -eq 0 ]
    then
      ofset=${#search_str}
      length=$((${#name}-$ofset))
      name=$replace_str${name:$ofset:$length}
    fi
  fi
  echo $name
}

process_episode(){
  name=$1
  match=$(echo $name | grep -oE 'S[0-9]{1,}X[0-9]{1,}')
  if [ ! -z "$match" ]; then 
    name=${name/$match/"_"$match"_"}
    echo "SH-" > "$gteam_path"
    echo $name
    return
  fi
  match=$(echo $name | grep -oE '[0-9]{1,}X[0-9]{1,}')
  if [ ! -z "$match" ]; then 
    name=${name/$match/"_S"$match"_"}
    echo "SH-" > "$gteam_path"
    echo $name
    return
  fi
  echo $name
}

correct_desc_info(){
  local desc=$1
  result=""
  country=""
  IFS='-' read -ra arr <<< "$desc"
  #find country
  while IFS= read -r line
  do
    line=$(echo ${line^^})
    for i in "${!arr[@]}";do
      if [[ "${arr[$i]}" == "$line" ]];then
        country=$line
        unset 'arr[$i]'
        break
      fi
    done
    if [ ! -z "$country" ];then
      break
    fi
  done < "$COUNTRY_FILE"

  for i in "${!arr[@]}";do
    value="${arr[$i]}"
    if [ ${#value} -lt 2 ];then continue; fi
    result+="$value";
  done

  if [ ! -z "$country" ] && [ ! -z "$result" ];then
    result=$country"_"$result
  else
    result="$country$result"
  fi
  echo $result
}

remove_blacklist_keyword(){
  local name="$1"
  shift
  for i in "${NEGLECTS_KEYWORD[@]}";do
    name=${name//"$i"/""}
  done
  #replace some specific key
  name=$(check_position_replace "$name" "ARA-" "AR-")
  name=$(check_position_replace "$name" "ESP-" "ES-")
  name=$(check_position_replace "$name" "SPA-" "ES-")

  name=${name/"XEP"/"X0"}
  name=${name/"RT-60"/"RT"}
  name=${name/"-60-"/"-"}
  name=${name/"EN-EN"/"EN-EG"}
  name=${name/"FINAL-SUBS"/"SUB"}
  name=${name/"FINAL-SUB"/"SUB"}
  name=${name/"SUBS"/"SUB"}
  name=${name/"FINAL-CLEAN"/"CLEAN"}
  name=${name/"FINAL-YT"/"YT"}
  name=${name/"FINAL-FB"/"FB"}
  name=${name/"FINAL-TW"/"TW"}
  name=${name/"FINAL-IG"/"IG"}
  name=${name/"DDMMYY"/""}
  echo $name
}

order_movie_element(){
  local old_name="$1"
  local name="$2"
  local path="$3"
  lang=""
  team=""
  desc=""
  date=""
  #get date here
  match=$(echo $name | grep -oE '[0-9]{2}[0-9]{2}[0-9]{4}')
  if [ -z "$match" ];then
    match=$(echo $name | grep -oE '[0-9]{2}[0-9]{2}[0-9]{2}')
    if [ ! -z "$match" ] && [ ${#match} -eq 6 ];then
        date=$(echo $match | sed 's/[^0-9]//g')
        name=${name/"$match"/""}
    fi
  else
    if [ ${#match} -eq 8 ];then
      date=$(echo $match | sed 's/[^0-9]//g')
      date=${date:0:4}${date:6:2}
      name=${name/"$match"/""}
    fi
  fi

  #correct date
  if [ ! -z "$date" ];then
    dd=${date:0:2}
    mm=${date:2:2}
    yy=${date:4:2}
    if [ $mm -gt 12 ];then date=$mm$dd$yy; fi
  fi
  
  IFS='-' read -ra arr <<< "$name"
  count=${#arr[@]}
  tmpSuffix=""
  for i in "${!arr[@]}";do
    value=${arr[$i]}
    #get language
    if [ ${#value} -eq 2 ] && [[ "${LANGUAGES[@]}" =~ "$value" ]]; then
      lang=$value"-"
      continue
    fi
    #get team, desc
    if [ ${#value} -eq 2 ] && [[ "${TEAMS[@]}" =~ $value ]]; then
      team=$value"-"
      continue
    elif [[ $value == "VJ" ]] || [[ $value == "PL" ]];then
      team="NG-"
      continue
    fi
    # remove repeated character (XX)
    match=$(echo $value | grep -oE '(X)\1{1,}')
    if [ ! -z $match ];then value=${value//"$match"/""}; fi
    # get suffix, only process suffix with movie type
    if is_suffix $value;then
      if [ -z $tmpSuffix ];then
        tmpSuffix="$value"
      else
        tmpSuffix=$tmpSuffix-$value
      fi
    else
      if [ ! -z $value ];then desc+="$value-"; fi
    fi
  done
  echo "$tmpSuffix" > "$gsuffix_path";

  if [ -z "$team" ];then team="RT-"; fi

  #remove "-" at the end of desc
  index=$((${#desc} -1))
  if [ $index -gt 0 ];then desc=${desc:0:index}; fi
  desc=$(correct_desc_info "$desc")

  if [ -z "$lang" ] && [ ! -z "$default_lang" ];then
    lang="$default_lang-"
  fi

  if [ -z "$lang" ];then name="$team$desc"
  else name="$lang$team$desc";fi

  #append date
  if [ -z $date ]; then date=$(date +'%m%d%y'); fi
  name="$name-$date"
  #append suffix if type is movie
  if [ ! -z $tmpSuffix ];then name=$name-$tmpSuffix
  else name=$name"-RAW";fi
  echo $name
}

standardized_name(){
  local file_path="$1"
  echo "" > "$gsuffix_path"
  echo "" > "$gteam_path"
  
  local old_name=$(basename "$file_path")
  local path=$(dirname "$file_path")
  local name=$old_name
  #Remove .extension
  if [[ "$name" == *"."* ]]; then
    ext=$(echo $name | cut -d '.' -f2-)
    name=$(echo $name | cut -d '.' -f 1)
  fi

  # convert from UTF-8 to ASCII 
  name=$(echo "$name" | iconv -f UTF-8 -t ASCII//TRANSLIT)

  #Replace space by -
  name=$(echo "$name" | sed -e "s/ /-/g")

  #Remove illegal characters
  name=$(echo $name | sed 's/[^.a-zA-Z0-9_-]//g')

  #Convert lower case to upper case
  name=$(echo ${name^^})

  match=$(echo $name | grep -o 'SALEET')
  if [ ! -z "$match" ];then
    name=${name/$match/""}
    echo "SH-SA_" > "$gteam_path"
  fi

  match=$(echo $name | grep -o 'REEM')
  if [ ! -z "$match" ];then
    name=${name/$match/""}
    echo "SH-RM_" > "$gteam_path"
  fi

  match=$(echo $name | grep -oE '_[0-9]{6}')
  if [ ! -z "$match" ];then
    new_str="-"${match:1}
    name=${name/$match/$new_str}
  fi

  for i in "${!SUFFIX_LISTS[@]}";do
    search_str="_""${SUFFIX_LISTS[$i]}"
    replace_str="-""${SUFFIX_LISTS[$i]}"
    name=${name/$search_str/$replace_str}
  done

  #remove neglect keyword
  name=$(remove_blacklist_keyword "$name")
  if [[ $name = *_ ]]; then name=${name::-1}; fi
  if [[ $name = _* ]]; then name=${name:1}; fi

  name=$(process_episode "$name")

  # reorder element
  name=$(order_movie_element "$old_name" "$name" "$path")

  if [ ! -z ${ext+x} ]; then name=$name".$ext"; fi
  #Remove duplicate chracter (_, -)
  tmp_name=""
  pc=""
  for (( i=$((${#name} -1)); i>=0; i-- )); do
    c="${name:$i:1}"
    if [[ $c == "_" ]] || [[ $c == "-" ]];then
      if [[ $pc == "_" ]] || [[ $pc == "-" ]]; then continue;
      else tmp_name=$c$tmp_name; fi
    else tmp_name=$c$tmp_name; fi
    pc=$c
  done
  name=$tmp_name

  name=${name/"ES-ST"/"ES-RT"}
  name=${name/"E-SH"/"ES-RT"}
  echo $name
}

get_target_folder_by_ext(){
    local file="$1"
    file_ext=$(echo "$file" | rev | cut -d'.' -f 1 | rev)
    if [[ $file_ext == "mp4" ]] || [[ $file_ext == "MP4" ]];then result="$MP4_PATH";
    elif [[ $file_ext == "mov" ]] || [[ $file_ext == "MOV" ]];then result="$MOV_MXF_PATH";
    elif [[ $file_ext == "mxf" ]] || [[ $file_ext == "MXF" ]];then result="$MOV_MXF_PATH";
    else result="$OTHER_PATH";fi
    echo $result
}

find_video_suffix(){
    local file_name="$1"

    for val in "${SUFFIX_LISTS[@]}"; do
        val_ext="-""$val"
        if [[ "$file_name" == *"$val_ext"* ]];then
            echo $val
            return
        fi
    done
}

dummy_test(){
    local file_path="$1"
    local report_path="$2"
    count=1
    while IFS= read -r line
    do
        old_name=$(echo ${line^^})
        if [ -z "$old_name" ]; then continue; fi
        echo "($count)File: $line"

        # precheck file name
        match=$(echo $old_name | grep -o 'TEST')
        if [ ! -z "$match" ];then
            match=$(echo $old_name | grep -o 'PROTEST')
            if [ -z "$match" ];then
                echo "Invalid file name. Ignored!"
                echo "Move to : $DELETED_PATH"
                echo "$line, - ,0, $DELETED_PATH" >> "$report_path"
                echo "---------------------"
                echo
                continue
            fi
        fi

        new_name=$(standardized_name "$old_name")
        echo "New name : $new_name"
        target_folder=$(get_target_folder_by_ext "$line")
        echo "Move to : $target_folder"
        echo "$line, $new_name,0, $target_folder" >> "$report_path"
        echo "---------------------"
        echo
        count=$(($count + 1))
    done < "$file_path"
}

process_match_video(){
    local file_path="$1"
    local report_path="$2"
    size=$(get_file_size "$file_path")
    old_name=$(basename "$file_path")
    match=$(echo $old_name | grep -o 'TEST')
    if [ ! -z "$match" ];then
        match=$(echo $old_name | grep -o 'PROTEST')
        if [ -z "$match" ];then
            echo "Invalid file name. Ignored!"
            echo "Move to : $DELETED_PATH"
            if [[ $mode == "RUN" ]];then
                mv -f "$file_path" "$DELETED_PATH"
            fi
            echo "$(basename "$file_path"), - ,0, $DELETED_PATH" >> "$report_path"
            return
        fi
    fi
    
    new_name=$(standardized_name "$old_name")
    echo "New name : $new_name"
    if [[ $mode == "RUN" ]];then
        if [[ "$(basename "$file_path")" != "$new_name" ]];then
            mv -f "$file_path" "$(dirname "$file_path")/$new_name"
        fi
    fi

    file_path="$(dirname "$file_path")/$new_name"
    target_folder=$(get_target_folder_by_ext "$file_path")
    echo "Move to : $target_folder"
    if [[ $mode == "RUN" ]];then
        mv -f "$file_path" "$target_folder"
    fi
    echo "$old_name, $new_name,0, $target_folder" >> "$report_path"

}

main(){
    total=0
    total_size=0
    
    if [ ! -f "$COUNTRY_FILE" ]; then
        echo "Not found country file : " $COUNTRY_FILE
        exit 1
    fi

    # validate argument
    validate=0
    if [ ! -d "$MP4_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [MP4_PATH][$MP4_PATH]${NC}\n"; validate=1; fi
    if [ ! -d "$MOV_MXF_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [MOV_MXF_PATH][$MOV_MXF_PATH]${NC}\n"; validate=1; fi
    if [ ! -d "$OTHER_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [OTHER_PATH][$OTHER_PATH]${NC}\n"; validate=1; fi
    if [ ! -d "$LOG_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [LOG_PATH][$LOG_PATH]${NC}\n"; validate=1; fi
    if [ ! -d "$DELETED_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [DELETED_PATH][$DELETED_PATH]${NC}\n"; validate=1; fi

    if [ -f "$REPORT_FILE" ];then
        rm -rf "$REPORT_FILE"
    fi
    touch "$REPORT_FILE"
    echo "Old Name, New Name, Size, Move to" > "$REPORT_FILE"
    
    echo "Database file : $DATABASE_FILE"
    if [[ $mode == "RUN" ]];then
        echo "Run the script in execute mode"
    elif [[ $mode == "TEST" ]];then
        echo "Run the script in test mode (folder input)"
    elif [[ $mode == "DUMMY" ]];then
        echo "Run the script in test mode (plain text input)"
    fi
    echo "-------------------------------"
    if [[ -f "$INPUT" ]]; then
        # Input is text file
        echo "Input text file : $INPUT"
        dummy_test "$INPUT" "$REPORT_FILE"
    else
        # Input is directorys
        # Collect all input folder
        list_dir=""
        for argument in "${INPUT[@]}"; do
            list_dir="${argument} $list_dir "
        done
        echo "List input directory : $list_dir"
        echo "-------------------------------"
        echo "Finding video in folder ..."
        video_files=$(find $list_dir -type f \( -iname \*.mov -o -iname \*.mxf -o -iname \*.mp4 \))
        while IFS= read -r file; do
            size=$(get_file_size "$file")
            total_size=$(($total_size + $size))
            echo "($total)File ($(convert_size $size)): $file"
            process_match_video "$file" "$REPORT_FILE"
            echo "---------------------"
            echo
            total=$(($total + 1)) 
        done < <(printf '%s\n' "$video_files")
    fi
    
    rm -rf $gline_path
    rm -rf $gteam_path
    rm -rf $gsuffix_path
    echo
    echo "===================="
    printf "%10s %-15s : $total\n" "-" "Total files"
    printf "%10s %-15s : $(convert_size $size)\n" "-" "Total size"
    
    printf "%10s %-15s : $log_file \n" "-" "Log file"
    printf "%10s %-15s : $REPORT_FILE \n" "-" "Report file"
    echo "Bye"
}
log_file="$LOG_PATH/matching_video_log.txt"

main | while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done | tee "$log_file"