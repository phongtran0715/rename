#!/bin/bash
RED='\033[0;31m'
YELLOW='\033[1;33m'
GRAY='\033[1;30m'
NC='\033[0m'

COUNTRY_FILE="countries.txt"
LANGUSGES=("AR" "EN" "FR" "ES")
TEAMS=("RT", "NG" "EG" "CT" "SH" "ST")
NEGLECTS_KEYWORD=("V1" "V2" "V3" "V4" "SQ" "-SW-" "-NA-" "FYT" "FTY" "SHORT" "SQUARE" "SAKHR"
  "KHEIRA" "TAREK" "TABISH" "ZACH" "SUMMAQAH" "HAMAMOU" "ITANI" "YOMNA" "COPY" "COPIED")
SUFFIX_LISTS=("SUB" "FINAL" "YT" "CLEAN" "TW" "TWITTER" "FB" "FACEBOOK" "YT" "YOUTUBE" "IG" "INSTAGRAM")

#Target folder name. Those folder will be created automaticlly if them don't exist
AR_OVER_DIR="/mnt/restore/S3UPLOAD/TEMP-AR/"
EN_OVER_DIR="/mnt/restore/S3UPLOAD/TEMP-EN/"
ES_OVER_DIR="/mnt/restore/S3UPLOAD/TEMP-ES/"
FR_OVER_DIR="FR-OVER"

AR_UNDER_DIR="/mnt/restore/S3UPLOAD/AR_Prod_LTO/"
EN_UNDER_DIR="/mnt/restore/S3UPLOAD/EN_Prod_LTO/"
ES_UNDER_DIR="/mnt/restore/S3UPLOAD/ES_Prod_LTO/"
FR_UNDER_DIR="FR-UNDER"

OTHER_DIR="/mnt/restore/__CHECK/"
DELETED_DIR="/mnt/restore/__DELETED/"

DATABASE_FILE="/mnt/restore/zipdata_db.csv"

#Video file size threshold
THRESHOLD=$((50 * 1024 * 1024)) #50Gb
DELETE_THRESHOLD=$((100 * 1024 * 1024)) #50Mb

declare -A ARR_VIDEOS

gsuffix_path="/tmp/.gsuffix"
gteam_path="/tmp/.gvideo_team"
gvideo_name_path="/tmp/.gvideo_name"

TOTAL_DEL_FILE=0
TOTAL_DEL_SIZE=0

function DEBUG()
{
  [ "$_DEBUG" == "on" ] && $@ || :
}

helpFunction()
{
  echo ""
  echo "Usage: $0 [option] folder_path [option] language"
  echo -e "Example : ./ZipMoonRC2.sh -c /home/jack/Video -l AR"
  echo -e "option:"
  echo -e "\t-c Check rename function"
  echo -e "\t-x Apply rename function"
  echo -e "\t-l Set language for file name"
  exit 1
}

while getopts "c:x:l:" opt
do
   case "$opt" in
      c ) INPUT="$OPTARG"
          mode="TEST";;
      x ) INPUT="$OPTARG"
          mode="RUN";;
      l ) default_lang="$OPTARG";;
      ? ) helpFunction ;;
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$INPUT" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

insert_db(){
  local old_name="$1"
  local new_name="$2"
  local size="$3"
  local path="$4"
  new_record="$1","$2","$3","$4"
  compare_str="$1","$2","$3"
  match=$(cat $DATABASE_FILE | grep "$compare_str")
  if [ ! -z "$match" ];then
    return # found
  else
    #not found , insert to db
    echo "$new_record" >> "$DATABASE_FILE"
  fi
}

is_suffix(){
  local data="$1"
  for i in "${!SUFFIX_LISTS[@]}";do
    if [[ "$data" == "${SUFFIX_LISTS[$i]}" ]];then
      return 0
    fi
  done
  return 1 #false
}

list_contain(){
  item=$1
  shift
  arr=("${@}")
  for key in ${arr[@]}; do
    if [[ $key == $item ]];then
      return 0; #found
    fi
  done
  return 1 # not found
}

convert_size(){
  printf %s\\n $1 | LC_NUMERIC=en_US numfmt --to=iec
}

get_target_folder(){
  lang=$1
  size=$2
  if [ $size -gt $THRESHOLD ];then
    if [[ $lang == "AR" ]];then result="$AR_OVER_DIR";
    elif [[ $lang == "EN" ]];then result="$EN_OVER_DIR";
    elif [[ $lang == "ES" ]];then result="$ES_OVER_DIR";
    elif [[ $lang == "FR" ]];then result="$FR_OVER_DIR";
    else result="$OTHER_DIR";fi
  else
    if [[ $lang == "AR" ]];then result="$AR_UNDER_DIR";
    elif [[ $lang == "EN" ]];then result="$EN_UNDER_DIR";
    elif [[ $lang == "ES" ]];then result="$ES_UNDER_DIR";
    elif [[ $lang == "FR" ]];then result="$FR_UNDER_DIR";
    else result="$OTHER_DIR";fi
  fi
  echo $result
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
  else
    full_path=$path"/$old_name"
    if [[ -f "$full_path" ]]; then
      epoch_time=$(stat -c "%Y" -- "$full_path")
    fi
    if [ ! -z $epoch_time ]; then date=$(date -d @$epoch_time +"%d%m%y"); fi
  fi
  
  IFS='-' read -ra arr <<< "$name"
  count=${#arr[@]}
  tmpSuffix=""
  for i in "${!arr[@]}";do
    value=${arr[$i]}
    #get language
    if [ ${#value} -eq 2 ] && [[ "${LANGUSGES[@]}" =~ "$value" ]]; then
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
  read gteam < "$gteam_path"
  if [ ! -z $gteam ];then team=$gteam; fi

  #remove "-" at the end of desc
  index=$((${#desc} -1))
  if [ $index -gt 0 ];then desc=${desc:0:index}; fi
  desc=$(correct_desc_info "$desc")

  if [ -z "$lang" ] && [ ! -z "$default_lang" ];then
    lang="$default_lang-"
  fi

  if [ -z "$lang" ];then name="$team$desc"
  else name="$lang$team$desc";fi
  echo "$name" > "$gvideo_name_path"

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

  DEBUG echo "000 : $file_path"
  local old_name=$(basename "$file_path")
  local path=$(dirname "$file_path")
  local name=$old_name
  #Remove .extension
  if [[ "$name" == *"."* ]]; then
    ext=$(echo $name | cut -d '.' -f2-)
    name=$(echo $name | cut -d '.' -f 1)
  fi
  DEBUG echo "001 : $name"

  # convert from UTF-8 to ASCII 
  name=$(echo "$name" | iconv -f UTF-8 -t ASCII//TRANSLIT)

  #Replace space by -
  name=$(echo "$name" | sed -e "s/ /-/g")

  #Remove illegal characters
  name=$(echo $name | sed 's/[^.a-zA-Z0-9_-]//g')
  DEBUG echo "002 : $name"

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
  DEBUG echo "003 : $name"

  #remove neglect keywork
  name=$(remove_blacklist_keyword "$name")
  if [[ $name = *_ ]]; then name=${name::-1}; fi
  if [[ $name = _* ]]; then name=${name:1}; fi
  DEBUG echo "004 : $name"

  name=$(process_episode "$name")
  DEBUG echo "005 : $name"

  #reorder element
  name=$(order_movie_element "$old_name" "$name" "$path")
  if [ ! -z ${ext+x} ]; then name=$name".$ext"; fi
  DEBUG echo "006 : $name"
  #Remove duplicate chracter (_, -)
  tmp_name=""
  pc=""
  for (( i=$((${#name} -1)); i>=0; i-- )); do
  # for (( i=0; i<${#name}; i++ )); do
    c="${name:$i:1}"
    if [[ $c == "_" ]] || [[ $c == "-" ]];then
      if [[ $pc == "_" ]] || [[ $pc == "-" ]]; then continue;
      else tmp_name=$c$tmp_name; fi
    else tmp_name=$c$tmp_name; fi
    pc=$c
  done
  name=$tmp_name
  echo $name
}

db_check(){
  local file_name="$1"
  match=$(cat "$DATABASE_FILE" | cut -f2 -d"," | grep "$file_name")
  if [ ! -z "$match" ];then
    return 0 #found
  else
    return 1 # not found
  fi
}

check_video_file(){
  local file_path="$1"
  local log_path="$2"
  local index=$3
  count=1
  echo "----------"
  # check rename video file
  old_name=$(basename "$file_path")
  new_name=$(standardized_name "$file_path")
  old_no_ext=$(echo $old_name | cut -f 1 -d '.')
  new_no_ext=$(echo $new_name | cut -f 1 -d '.')
  if [[ -f "$file_path" ]];then fileSize=$(stat -c%s "$file_path"); fi

  # check file name is matched with origin file name in DB or not
  read video_name < "$gvideo_name_path"
  if ! db_check "$video_name";then
    printf "${YELLOW}($index)File\t: %-50s - %s${NC}\n" "$old_name" "$new_name"
    printf "${YELLOW}File not match DB - Moved to : $OTHER_DIR${NC}\n"
    return
  fi

  # check new zip file existed or not
  if list_contain "$new_no_ext" "${!ARR_VIDEOS[@]}";then
    #found
    printf "${RED}($index)File\t: %-50s - %s${NC}\n" "$old_name" "$new_no_ext"
    printf "${RED}File existed (*Deleted* - Size : %s )${NC}\n" "$(convert_size $fileSize)"
    TOTAL_DEL_FILE=$(($TOTAL_DEL_FILE + 1))
    TOTAL_DEL_SIZE=$(($TOTAL_DEL_SIZE + $fileSize))
    return
  fi
  # Check suffix
  read gsuffix < "$gsuffix_path"
  if [ -z "$gsuffix" ];then
    printf "${GRAY}($count) \t: %-50s -> Invalid suffix. Ignored!${NC}\n" "$old_no_ext"
    count=$(($count +1))
    continue;
  fi
  printf "($index)File\t: %-50s -> %-50s\n" "$old_no_ext" "$new_no_ext"
  ARR_VIDEOS+=(["$new_no_ext"]=fileSize)
  dir_name=$(dirname "$file_path")

  # move to target folder
  target_folder=$(get_target_folder ${new_no_ext:0:2} $fileSize)
  echo -e "Size\t:" "$(convert_size $fileSize)" " - Moved to : $target_folder"
  echo "$old_no_ext,$new_no_ext,$(convert_size $fileSize),$target_folder"  >> $log_path
}

process_video_file(){
  local file_path="$1"
  local index=$2
  count=1
  echo "----------"
  # check rename video file
  old_name=$(basename "$file_path")
  new_name=$(standardized_name "$file_path")
  old_no_ext=$(echo $old_name | cut -f 1 -d '.')
  new_no_ext=$(echo $new_name | cut -f 1 -d '.')
  if [[ -f "$file_path" ]]; then fileSize=$(stat -c%s "$file_path"); fi
  dir_name=$(dirname "$file_path")

  # check file name is matched with origin file name in DB or not
  read video_name < "$gvideo_name_path"
  if ! db_check "$video_name";then
    printf "${YELLOW}($index)File\t: %-50s - %s${NC}\n" "$old_name" "$new_name"
    printf "${YELLOW}File not match DB - Moved to : $OTHER_DIR${NC}\n"
    mv -f "$file_path" "$OTHER_DIR"
    return
  fi

  # check new file existed or not
  if list_contain "$new_no_ext" "${!ARR_VIDEOS[@]}";then
    #found
    printf "${RED}($index)File\t: %-50s - %s${NC}\n" "$old_name" "$new_no_ext"
    printf "${RED}File existed (*Deleted* - Size : %s )${NC}\n" "$(convert_size $fileSize)"
    mv -f "$file_path" "$DELETED_DIR"
    TOTAL_DEL_FILE=$(($TOTAL_DEL_FILE + 1))
    TOTAL_DEL_SIZE=$(($TOTAL_DEL_SIZE + $fileSize))
    return
  else
    #not found
    printf "($index)File\t: %-50s  -> %-50s\n" "$old_no_ext" "$new_no_ext"
    # Rename video file
    if [[ "$old_name" != "$new_name" ]];then
      mv -f "$dir_name/$old_name" "$dir_name/$new_name"
    fi
    ARR_VIDEOS+=(["$new_no_ext"]=fileSize)
  fi

  # move to target folder
  target_folder=$(get_target_folder ${new_no_ext:0:2} $fileSize)
  echo -e "Size\t: " "$(convert_size $fileSize)" " - Moved to : $target_folder"
  if [ ! -f "$target_folder/$new_name" ];then
    mv -f "$dir_name/$new_name" "$target_folder"
    count=$(($count +1))
  else
    return
  fi
}

main(){
  total=0
  echo "" > invalid_name.txt
  if [ ! -f "$COUNTRY_FILE" ]; then
    printf "${YELLOW}Not found country file : $COUNTRY_FILE${NC}\n"
    exit 1
  fi

  if [ ! -f "$DATABASE_FILE" ]; then
    printf "${YELLOW}Not found database file : $DATABASE_FILE${NC}\n"
  fi

  validate=0
  if [ ! -d "$AR_OVER_DIR" ]; then printf "${YELLOW}Warning! Directory doesn't existed [AR_OVER_DIR][$AR_OVER_DIR]${NC}\n"; validate=1; fi
  if [ ! -d "$EN_OVER_DIR" ]; then printf "${YELLOW}Warning! Directory doesn't existed [EN_OVER_DIR][$EN_OVER_DIR]${NC}\n"; validate=1; fi
  if [ ! -d "$ES_OVER_DIR" ]; then printf "${YELLOW}Warning! Directory doesn't existed [ES_OVER_DIR][$ES_OVER_DIR]${NC}\n"; validate=1; fi
  if [ ! -d "$FR_OVER_DIR" ]; then printf "${YELLOW}Warning! Directory doesn't existed [FR_OVER_DIR][$FR_OVER_DIR]${NC}\n"; validate=1; fi

  if [ ! -d "$AR_UNDER_DIR" ]; then printf "${YELLOW}Warning! Directory doesn't existed [AR_UNDER_DIR][$AR_UNDER_DIR]${NC}\n"; validate=1; fi
  if [ ! -d "$EN_UNDER_DIR" ]; then printf "${YELLOW}Warning! Directory doesn't existed [EN_UNDER_DIR][$EN_UNDER_DIR]${NC}\n"; validate=1; fi
  if [ ! -d "$ES_UNDER_DIR" ]; then printf "${YELLOW}Warning! Directory doesn't existed [ES_UNDER_DIR][$ES_UNDER_DIR]${NC}\n"; validate=1; fi
  if [ ! -d "$FR_UNDER_DIR" ]; then printf "${YELLOW}Warning! Directory doesn't existed [FR_UNDER_DIR][$FR_UNDER_DIR]${NC}\n"; validate=1; fi

  if [ ! -d "$DELETED_DIR" ]; then printf "${YELLOW}Warning! Directory doesn't existed [DELETED_DIR][$DELETED_DIR]${NC}\n"; validate=1; fi
  if [ ! -d "$OTHER_DIR" ]; then printf "${YELLOW}Warning! Directory doesn't existed [OTHER_DIR][$OTHER_DIR]${NC}\n"; validate=1; fi
  
  if [[ -d "$INPUT" ]]; then
    # directory
    log_path=$(echo $(dirname "$INPUT"))"/"$(echo $(basename "$INPUT")).csv
    if [[ $mode == "TEST" ]];then 
      echo "OLD VIDEO NAME,NEW VIDEO NAME,VIDEO SIZE,MOVED TO" > $log_path;
    fi
    #list all file sort by size , exclude folder
    files=$(ls -lSQ "$INPUT" |  grep -v '^d' | cut -f2 -d "\"")
    while read file; do
      file="$INPUT/$file"
      if [ ! -f "$file" ];then continue;fi
      total=$((total+1))
      if [[ $mode == "TEST" ]];then
        check_video_file "$file" "$log_path" $total
      else
        process_video_file "$file" $total
      fi
      echo
    done <<< "$files"
  else
    echo "$INPUT is not valid"
    exit 1
  fi

  echo "=============="
  if [[ $mode == "TEST" ]];then
    echo "Log file info:"
    printf "%10s %-15s : $log_path \n" "-" "Full log"
    echo
  fi
  echo "File info:"
  printf "%10s %-15s : $total \n" "-" "Total file"
  printf "%10s %-15s : $TOTAL_DEL_FILE\n" "-" "Deleted file"
  printf "%10s %-15s : %s\n" "-" "Deleted size" "$(convert_size $TOTAL_DEL_SIZE)"
}
main
