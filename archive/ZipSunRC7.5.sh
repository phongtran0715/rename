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
SUB_DIR_LISTS=("CUT" "EXPORT")

#Target folder name. Those folder will be created automaticlly if them don't exist
AR_OVER_DIR="/mnt/restore/S3UPLOAD/TEMP-AR/"
EN_OVER_DIR="/mnt/restore/S3UPLOAD/TEMP-EN/"
ES_OVER_DIR="/mnt/restore/S3UPLOAD/TEMP-ES/"
FR_OVER_DIR="FR-OVER"

AR_UNDER_DIR="/mnt/restore/S3UPLOAD/AR-UNDER/"
EN_UNDER_DIR="/mnt/restore/S3UPLOAD/EN-UNDER/"
ES_UNDER_DIR="/mnt/restore/S3UPLOAD/ES-UNDER/"
FR_UNDER_DIR="FR-UNDER"

AR_HOLD_DIR="/mnt/restore/R1084-AR/"
EN_HOLD_DIR="/mnt/restore/R1055-EN/"
ES_HOLD_DIR="/mnt/restore/R1200-ES/"
FR_HOLD_DIR="FR-HOLD"

OTHER_DIR="/mnt/restore/__CHECK/"
DELETED_DIR="/mnt/restore/__DEL/"

LOG_DIR="/mnt/restore/log/"
TMP_DIR="/mnt/restore/tmp/"
DATABASE_FULL="/mnt/restore/full_db.csv"
DATABASE_AR="/mnt/restore/ar_db.csv"
DATABASE_EN="/mnt/restore/en_db.csv"
DATABASE_ES="/mnt/restore/es_db.csv"

TARGET_DIR_LIST=( "$AR_OVER_DIR" "$EN_OVER_DIR" "$ES_OVER_DIR" "$FR_OVER_DIR"
  "$AR_UNDER_DIR" "$EN_UNDER_DIR" "$ES_UNDER_DIR" "$FR_UNDER_DIR"
  "$AR_HOLD_DIR" "$EN_HOLD_DIR" "$ES_HOLD_DIR" "$FR_HOLD_DIR")

#Zip file size threshold
THRESHOLD=$((150 * 1024 * 1024 * 1024)) #150Gb
DELETE_THRESHOLD=$((25 * 1024 * 1024)) #25Mb

declare -A ARR_ZIPS
declare -A ARR_MOVIES

gsuffix_path="/tmp/.gsuffix"
gteam_path="/tmp/.gteam"
gzip_date_path="/tmp/.gzip_date"
gzip_name_path="/tmp/.gzip_name"

TOTAL_DEL_ZIP_FILE=0
TOTAL_DEL_ZIP_SIZE=0
TOTAL_NON_LANG_FILE=0

TOTAL_MEDIA_FILE=0
TOTAL_DEL_MEDIA_FILE=0
TOTAL_DEL_MEDIA_SIZE=0

function DEBUG()
{
  [ "$_DEBUG" == "msg" ] && $@ || :
}

helpFunction()
{
  echo ""
  echo "Usage: $0 [option] folder_path [option] language"
  echo -e "Example : ./rename -c /home/jack/Video -l AR"
  echo -e "option:"
  echo -e "\t-d Manula test with input text file"
  echo -e "\t-c Check rename function"
  echo -e "\t-x Apply rename function"
  echo -e "\t-l Set language for file name"
  exit 1
}

while getopts "d:c:x:l:t:" opt
do
   case "$opt" in
      d ) INPUT="$OPTARG"
          mode="DUMMY";;
      c ) INPUT="$OPTARG"
          mode="TEST";;
      x ) INPUT="$OPTARG"
          mode="RUN";;
      l ) default_lang="$OPTARG";;
      t ) timestamp="$OPTARG";;
      ? ) helpFunction ;;
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$INPUT" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

create_group(){
    local input_path="$1"
    count=0
    if [ ! -d "$input_path" ]; then 
        return
    fi
    # get all zip file in this directory
    files=$(ls -S "$input_path"| egrep '\.zip$|\.Zip$|\.ZIP$')
    while read file_name; do
      if [ -z "$file_name" ];then continue; fi
      name_no_ext=$(echo $file_name | cut -f 1 -d '.')
      path="$input_path/$name_no_ext"
      # create folder
      mkdir -p "$path"
      # move file to folder
      mv -f "$path"* "$path/" > /dev/null 2>&1
      count=$((count+1))
    done <<< "$files"
}

get_db_file(){
  local name="$1"
  lang=$(echo "$name" | cut -f1 -d"-")
  if [[ $lang == "AR" ]];then
    result="$DATABASE_AR"
  elif [[ $lang == "EN" ]]; then
    result="$DATABASE_EN"
  elif [[ $lang == "ES" ]]; then
    result="$DATABASE_ES"
  else
    result=""
  fi
  echo $result
}

insert_db(){
  local old_name="$1"
  local new_name="$2"
  local size="$3"
  local path="$4"
  new_record="$1","$2","$3","$4"
  compare_str="$2","$3"
  db_children_file=$(get_db_file "$new_name")
  #create db file if ti doesn't existed
  if [ ! -f "$db_children_file" ];then
    touch "$db_children_file"
  fi
  #insert to children 
  if [ ! -z "$db_children_file" ];then
    match=$(cat $db_children_file | grep "$compare_str")
    if [ -z "$match" ];then
      echo "$new_record" >> "$db_children_file"
    fi
  fi
  
  if [ ! -f "$DATABASE_FULL" ];then
    touch "$DATABASE_FULL"
  fi
  # insert to db parent file
  match=$(cat "$DATABASE_FULL" | grep "$compare_str")
  if [ -z "$match" ];then
    echo "$new_record" >> "$DATABASE_FULL"
  fi
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

is_subdir(){
  local dir="$1"
  base_dir=$(echo $(basename "$dir"))
  base_dir=$(echo ${base_dir^^})
  for i in "${!SUB_DIR_LISTS[@]}";do
    if [[ "$base_dir" == *"${SUB_DIR_LISTS[$i]}"* && "$base_dir" != *"PRV"* ]];then
      return 0 #true
    fi
  done
  return 1 #false
}

validate_zip_name(){
  local file_name="$1"
  # validate number part
  IFS='-' read -ra arr <<< "$file_name"
  if [ ${#arr[@]} -ne 4 ];then
    return  1 #invalid
  else
    return 0
  fi
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

order_zip_element(){
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
    full_path="$path/$old_name"
    if [[ -f "$full_path" ]]; then
      epoch_time=$(stat -c "%Y" -- "$full_path")
    fi
    if [ ! -z $epoch_time ]; then date=$(date -d @$epoch_time +"%d%m%y"); fi
  fi
  if [[ $mode != "DUMMY" ]];then
    date=$(correct_zip_datetime "$path/$old_name" "$date")
  fi
  echo "$date" > "$gzip_date_path"

  IFS='-' read -ra arr <<< "$name"
  count=${#arr[@]}
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
    if [ ! -z $value ];then desc+="$value-"; fi
  done

  if [ -z "$team" ];then team="RT-"; fi
  read gteam < "$gteam_path"
  if [ ! -z $gteam ];then team=$gteam; fi

  index=$((${#desc} -1))
  if [ $index -gt 0 ];then desc=${desc:0:index}; fi
  desc=$(correct_desc_info "$desc")

  if [ -z "$lang" ] && [ ! -z "$default_lang" ];then
    lang="$default_lang-"
  fi
  if [ -z "$lang" ];then
    name="$team$desc"
  else
    name="$lang$team$desc"
  fi
  echo "$name" > "$gzip_name_path"
  #append date
  if [ -z $date ]; then date=$(date +'%m%d%y'); fi
  name="$name-$date"

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

  read gzip_date < "$gzip_date_path"
  if [ ! -z $gzip_date ];then date=$gzip_date;fi
  #remove "-" at the end of desc
  index=$((${#desc} -1))
  if [ $index -gt 0 ];then desc=${desc:0:index}; fi
  desc=$(correct_desc_info "$desc")

  if [ -z "$lang" ] && [ ! -z "$default_lang" ];then
    lang="$default_lang-"
  fi

  if [ -z "$lang" ];then name="$team$desc"
  else name="$lang$team$desc";fi

  read gzip_name < "$gzip_name_path"
  if [[ "$gzip_name" != "$name" ]];then
    if [[ $mode != "DUMMY" ]];then
      name="NOT-MATCH"
      echo "$name"
      return
    fi
  fi

  #append date
  if [ -z $date ]; then date=$(date +'%m%d%y'); fi
  name="$name-$date"
  #append suffix if type is movie
  if [ ! -z $tmpSuffix ];then name=$name-$tmpSuffix
  else name=$name"-RAW";fi
  echo $name
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

standardized_name(){
  local file_path="$1"
  local type="$2"
  echo "" > "$gsuffix_path"
  echo "" > "$gteam_path"
  if [[ $type == "ZIP" ]];then
    echo "" > "$gzip_date_path"
    echo "" > "$gzip_name_path"
  fi
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

  #remove neglect keywork
  name=$(remove_blacklist_keyword "$name")
  if [[ $name = *_ ]]; then name=${name::-1}; fi
  if [[ $name = _* ]]; then name=${name:1}; fi

  name=$(process_episode "$name")

  # reorder element
  if [[ $type == "MOVIE" ]];then
    name=$(order_movie_element "$old_name" "$name" "$path")
  else
    name=$(order_zip_element "$old_name" "$name" "$path")
  fi
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

get_hold_dir(){
  name="$1"
  result=""
  lang=$(echo $new_zip_name | cut -f1 -d"-")
    if [[ "$lang" != "$default_lang" ]]; then
      if [[ "$lang" == "AR" ]];then result="$AR_HOLD_DIR";
      elif [[ "$lang" == "EN" ]];then result="$EN_HOLD_DIR";
      elif [[ "$lang" == "ES" ]];then result="$ES_HOLD_DIR";
      elif [[ "$lang" == "FR" ]];then result="$FR_HOLD_DIR";
      else result=""; fi
    fi
  echo "$result"
}

dummy_test(){
  local file_path="$1"
  local log_path="$2"
  local zip_log_path="$3"
  count=1
  while IFS= read -r line
  do
    old_zip_name=$(echo ${line^^})
    if [ -z "$old_zip_name" ]; then continue; fi
    new_zip_name=$(standardized_name "$old_zip_name" "ZIP")
    if ! validate_zip_name $new_zip_name;then
      printf "${GRAY}($index)Zip\t: %-50s - %s - Invalid new zip name - Moved to : $OTHER_DIR${NC}\n" \
      "$old_zip_name" "$new_zip_name"
      continue
    fi
    echo "$old_zip_name,$new_zip_name"  >> $log_path
    echo "$new_zip_name"  >> $zip_log_path
    printf "($count) \t: %-50s -> %s\n" "$old_zip_name" "$new_zip_name"
    count=$(($count +1))
  done < "$file_path"
}

correct_zip_datetime(){
  local file_path="$1"
  local current_date="$2"
  #validate current datetime
  yy=${current_date:4:2}
  if [ $yy -le 18 ] && [ $yy -ge 16 ];then
    echo $current_date
    return
  fi
  tmpDirs=$(unzip -l "$file_path" "*/" | awk '/\/$/ { print $NF }')
  IFS=$'\n' read -rd '' -a dirs <<<"$tmpDirs"
  for d in "${dirs[@]}";do
    if is_subdir "$d";then
      # List all file in sub folder
      base_dir=$(echo $(basename "$d"))
      tmpFiles=$(unzip -Zl "$file_path" "*/$base_dir/*" | rev| cut -d '/' -f 1 | rev | sort -nr)
      IFS=$'\n' read -rd '' -a arrFiles <<<"$tmpFiles"
      for i in "${!arrFiles[@]}";do
        name=${arrFiles[$i]}
        match=$(echo $name | grep -oE '[0-9]{2}[0-9]{2}[0-9]{4}')
        if [ -z "$match" ];then
          match=$(echo $name | grep -oE '[0-9]{2}[0-9]{2}[0-9]{2}')
          if [ ! -z "$match" ] && [ ${#match} -eq 6 ];then
            date=$(echo $match | sed 's/[^0-9]//g')
          fi
        else
          if [ ${#match} -eq 8 ];then
            date=$(echo $match | sed 's/[^0-9]//g')
            date=${date:0:4}${date:6:2}
          fi
        fi
        #correct date
        if [ ! -z "$date" ];then
          dd=${date:0:2}
          mm=${date:2:2}
          yy=${date:4:2}
          if [ $mm -gt 12 ];then date=$mm$dd$yy; fi
          if [ $yy -le 18 ] && [ $yy -ge 16 ];then
            echo $date
            return
          fi
        fi
      done
    fi
  done
  echo "010117" #default 
}

check_zip_file(){
  declare -A ARR_MOVIES
  local file_path="$1"
  local log_path="$2"
  local zip_log_path="$3"
  local index=$4
  count=1
  echo "----------"
  # check rename zip file
  old_zip_name=$(basename "$file_path")
  new_zip_name=$(standardized_name "$file_path" "ZIP")
  old_no_ext=$(echo $old_zip_name | cut -f 1 -d '.')
  new_no_ext=$(echo $new_zip_name | cut -f 1 -d '.')
  if [[ -f "$file_path" ]];then zipSize=$(stat -c%s "$file_path"); fi
  # validate language if default lang not empty
  if [ ! -z $default_lang ];then
    hold_dir=$(get_hold_dir "$new_video_name")
    if [ ! -z "$hold_dir" ];then
      printf "${GRAY}($index) File : %-50s -> - Language not match - Moved to : %s${NC}\n" "$old_zip_name" "$hold_dir"
      echo "$old_no_ext,$new_no_ext,$(convert_size $zipSize),,$hold_dir"  >> $log_path
      TOTAL_NON_LANG_FILE=$(($TOTAL_NON_LANG_FILE + 1))
      return
    fi
  fi
  # validate new zip name
  if ! validate_zip_name $new_zip_name;then
    printf "${GRAY}($index)Zip\t: %-50s - %s - Invalid new zip name - Moved to : $OTHER_DIR${NC}\n" \
    "$old_zip_name" "$new_zip_name"
    return
  fi
  
  # validate zip size
  if [ $zipSize -lt $DELETE_THRESHOLD ]; then
    printf "${RED}($index)Zip\t: %-50s - Size : %s - Fize size invalid - Moved to : $DELETED_DIR${NC}\n" \
      "$old_zip_name" "$(convert_size $zipSize)"
    echo "$old_no_ext,under $(convert_size $DELETE_THRESHOLD),$(convert_size $zipSize),,$DELETED_DIR"  >> $log_path
    TOTAL_DEL_ZIP_FILE=$(($TOTAL_DEL_ZIP_FILE + 1))
    TOTAL_DEL_ZIP_SIZE=$(($TOTAL_DEL_ZIP_SIZE + $zipSize))
    return;
  fi

  # check new zip file existed or not
  if list_contain "$new_no_ext" "${!ARR_ZIPS[@]}";then
    #found
    printf "${RED}($index)Zip\t: %-50s -> %s ${NC}\n" "$old_zip_name" "$new_no_ext"
    printf "${RED}Size : $(convert_size $zipSize) - Duplicated - Move to $DELETED_DIR)${NC}\n"
    TOTAL_DEL_ZIP_FILE=$(($TOTAL_DEL_ZIP_FILE + 1))
    TOTAL_DEL_ZIP_SIZE=$(($TOTAL_DEL_ZIP_SIZE + $zipSize))
    return
  else
    #not found
    printf "($index)Zip\t: %-50s -> %-50s\n" "$old_no_ext" "$new_no_ext"
    ARR_ZIPS+=(["$new_no_ext"]=zipSize)
  fi
  zip_dir_name=$(dirname "$file_path")

  # move to target folder
  target_folder=$(get_target_folder ${new_no_ext:0:2} $zipSize)
  echo -e "Size\t:" "$(convert_size $zipSize)" " - Moved to : $target_folder"
  echo "$old_no_ext,$new_no_ext,$(convert_size $zipSize),,$target_folder"  >> $log_path
  echo "$new_no_ext"  >> $zip_log_path
  # insert_db "$old_zip_name" "$new_zip_name" "$zipSize" "$zip_dir_name"

  # Get root zip directory name
  root_dir_name=$(basename $(zipinfo -1 "$file_path" | head -n 1))
  # Read zip content file
  tmpDirs==$(unzip -Z -1 "$file_path" "*/" | cut -f 2 -d "/" | sort | uniq)
  IFS=$'\n' read -rd '' -a dirs <<<"$tmpDirs"
  
  for d in "${dirs[@]}";do
    if is_subdir "$d";then
      echo
      d=$(basename "$d")
      echo -e "Folder\t: [" $d "]"
      # List all file in sub folder
      tmpFiles=$(unzip -Zl -1 "$file_path" "$root_dir_name/$d/*" | egrep '.mp4|.MP4|.mov|.MOV|.mxf|.MXF' | sort -nr)
      tmpSizes=$(unzip -Zl "$file_path" "$root_dir_name/$d/*" | egrep '.mp4|.MP4|.mov|.MOV|.mxf|.MXF' | awk '{print $4}' | sort -nr)
      IFS=$'\n' read -rd '' -a arrFiles <<<"$tmpFiles"
      IFS=$'\n' read -rd '' -a arrSizes <<<"$tmpSizes"

      for i in "${!arrFiles[@]}";do
        # Only get file in root folder
        [[ $_DEBUG == "dbg" ]] && echo -e "Processing file : ${arrFiles[$i]}"
        num_path=$(echo "${arrFiles[$i]}" | grep -o '/' - | wc -l)
        if [ $num_path -ne 2 ];then continue;fi
        old_video_name=$(basename "${arrFiles[$i]}")
        new_video_name=$(standardized_name "$zip_dir_name/$old_video_name" "MOVIE")
        if [[ $new_video_name == "NOT-MATCH"* ]]; then
          printf "${GRAY}($count) \t: %-50s -> Not match with zip file name. Ignored!${NC}\n" "$old_video_name"
          count=$(($count +1))
          continue
        fi
        #check movie name have suffix or not
        read gsuffix < "$gsuffix_path"
        if [ -z "$gsuffix" ];then
          printf "${GRAY}($count) \t: %-50s -> Invalid suffix. Ignored!${NC}\n" "$old_video_name"
          count=$(($count +1))
          continue;
        fi
        TOTAL_MEDIA_FILE=$(($TOTAL_MEDIA_FILE + 1))
        if list_contain "$new_video_name" "${!ARR_MOVIES[@]}";then
          #found
          printf "${RED}($count)\t: %-50s -> %s ${NC}\n" "$old_video_name" "$new_video_name"
          printf "${RED}Size : $(convert_size ${arrSizes[$i]}) - Duplicated - Move to $DELETED_DIR)${NC}\n"
          count=$(($count +1))
          TOTAL_DEL_MEDIA_FILE=$(($TOTAL_DEL_MEDIA_FILE + 1))
          TOTAL_DEL_MEDIA_SIZE=$(($TOTAL_DEL_MEDIA_SIZE + ${arrSizes[$i]}))
          continue
        else
          #not found
          printf "($count) \t: %-50s -> $new_video_name\n" "$old_video_name"
          ARR_MOVIES+=(["$new_video_name"]=${arrSizes[$i]})
          target_folder=$(get_target_folder ${new_video_name:0:2} ${arrSizes[$i]})
          echo -e "Size\t:" "$(convert_size ${arrSizes[$i]})" " - Moved to : $target_folder"
        fi
        echo ",,,$d/$new_video_name,$target_folder" >> $log_path
        count=$(($count +1))
      done
    fi
  done
}

process_zip_file(){
  local file_path="$1"
  local log_path="$2"
  local zip_log_path="$3"
  local index=$4
  count=0
  echo "----------"
  # check rename zip file
  old_zip_name=$(basename "$file_path")
  new_zip_name=$(standardized_name "$file_path" "ZIP")
  old_no_ext=$(echo $old_zip_name | cut -f 1 -d '.')
  new_no_ext=$(echo $new_zip_name | cut -f 1 -d '.')
  if [[ -f "$file_path" ]]; then zipSize=$(stat -c%s "$file_path"); fi
  zip_dir_name=$(dirname "$file_path")
  
  # validate language if default lang not empty
  if [ ! -z $default_lang ];then
    hold_dir=$(get_hold_dir "$new_zip_name")
    if [ ! -z "$hold_dir" ];then
      printf "${YELLOW}($index) File : %-50s - Language invalid - Moving to : %s${NC}\n" "$old_zip_name" "$hold_dir"
      echo "$old_no_ext,$new_no_ext,$(convert_size $zipSize),,$hold_dir"  >> $log_path
      # pv "$zip_dir_name/$old_zip_name" > "$hold_dir/$old_zip_name"
      # rm -f "$zip_dir_name/$old_zip_name"
      mv -f "$zip_dir_name/$old_zip_name" "$hold_dir/"
      TOTAL_NON_LANG_FILE=$(($TOTAL_NON_LANG_FILE + 1))
      return
    fi
  fi

  # validate new zip name
  if ! validate_zip_name $new_zip_name;then
    printf "${GRAY}($index)Zip\t: %-50s - %s - Invalid new zip name - Moving to : $OTHER_DIR${NC}\n" \
    "$old_zip_name" "$new_zip_name"
    # pv "$zip_dir_name/$old_zip_name" > "$OTHER_DIR/$old_zip_name"
    # rm -f "$zip_dir_name/$old_zip_name"
    mv -f "$zip_dir_name/$old_zip_name" "$OTHER_DIR/"
    continue
  fi

  # validate zip size
  if [ $zipSize -lt $DELETE_THRESHOLD ]; then
    printf "${RED}($index)Zip\t: %-50s - Size : %s - File size invalid - Moving to : $DELETED_DIR${NC}\n" \
      "$old_zip_name" "$(convert_size $zipSize)"
    echo "$old_no_ext,under $(convert_size $DELETE_THRESHOLD),$(convert_size $zipSize),,$DELETED_DIR"  >> $log_path
    # pv "$zip_dir_name/$old_zip_name" > "$DELETED_DIR/$old_zip_name"
    # rm -f "$zip_dir_name/$old_zip_name"
    mv -f "$file_path" "$DELETED_DIR";
    TOTAL_DEL_ZIP_FILE=$(($TOTAL_DEL_ZIP_FILE +1))
    TOTAL_DEL_ZIP_SIZE=$(($TOTAL_DEL_ZIP_SIZE + $zipSize))
    return;
  fi

  # check new zip file existed or not
  if list_contain "$new_no_ext" "${!ARR_ZIPS[@]}";then
    #found
    printf "${RED}($index)Zip\t: %-50s -> %s ${NC}\n" "$old_zip_name" "$new_no_ext"
    printf "${RED}Size : $(convert_size $zipSize) - Duplicated - Move to $DELETED_DIR)${NC}\n"
    mv -f "$file_path" "$DELETED_DIR"
    # pv "$zip_dir_name/$old_zip_name" > "$DELETED_DIR/$old_zip_name"
    # rm -f "$zip_dir_name/$old_zip_name"
    TOTAL_DEL_ZIP_FILE=$(($TOTAL_DEL_ZIP_FILE + 1))
    TOTAL_DEL_ZIP_SIZE=$(($TOTAL_DEL_ZIP_SIZE + $zipSize))
    return
  else
    #not found
    printf "($index)Zip\t: %-50s  -> %-50s\n" "$old_no_ext" "$new_no_ext"
    if [[ "$old_zip_name" != "$new_zip_name" ]];then
      mv -f "$zip_dir_name/$old_zip_name" "$zip_dir_name/$new_zip_name"
    fi
    ARR_ZIPS+=(["$new_no_ext"]=zipSize)
  fi

  # move to target folder
  target_folder=$(get_target_folder ${new_no_ext:0:2} $zipSize)
  echo -e "Size\t: " "$(convert_size $zipSize)" " - Moving to : $target_folder"
  # pv "$zip_dir_name/$new_zip_name" > "$target_folder/$new_zip_name"
  # rm -f "$zip_dir_name/$new_zip_name"
  mv -f "$zip_dir_name/$new_zip_name" "$target_folder"
  file_path="$target_folder/$new_zip_name"
  zip_dir_name=$(dirname "$file_path")
  echo "$old_no_ext,$new_no_ext,$(convert_size $zipSize),,$target_folder"  >> $log_path
  echo "$new_no_ext"  >> $zip_log_path
  insert_db "$old_zip_name" "$new_zip_name" "$zipSize" "$zip_dir_name"
  echo

  # Read zip content file
  tmpDirs==$(unzip -Z -1 "$file_path" "*/" | cut -f 2 -d "/" | sort | uniq)
  IFS=$'\n' read -rd '' -a dirs <<<"$tmpDirs"

  unset sub_folder;
  for d in "${dirs[@]}";do
    if is_subdir "$d";then
      sub_folder+=("$d")
    fi
  done

  # Loop all sub dir, unzip video  
  if [ ${#sub_folder[@]} -gt 0 ];then
    # unzip
    rm -rf "$TMP_DIR"
    mkdir -p "$TMP_DIR"
    # Get root zip directory name
    root_dir_name=$(basename $(zipinfo -1 "$file_path" | head -n 1))
    for d in "${sub_folder[@]}";do
      echo -e "Folder ["$(basename $d)"]... "
      echo "Start unziping  ..."
      # List all file in sub folder
      tmpFiles=$(unzip -Zl -1 "$file_path" "$root_dir_name/$d/*" | egrep '.mp4|.MP4|.mov|.MOV|.mxf|.MXF' | sort -nr)
      IFS=$'\n' read -rd '' -a arrFiles <<<"$tmpFiles"
      for i in "${!arrFiles[@]}";do 
        # Only get file in root folder
        num_path=$(echo "${arrFiles[$i]}" | grep -o '/' - | wc -l)
        if [ $num_path -ne 2 ];then continue;fi
        video_size=$(unzip -Zl "$file_path" "${arrFiles[$i]}" | awk '{print $4}')
        echo "Unzip video ($(convert_size $video_size)): ${arrFiles[$i]}"
        unzip -jo -qq  "$file_path" "${arrFiles[$i]}" -d "$TMP_DIR"
        # unzip -jo  "$file_path" "${arrFiles[$i]}" -d "$TMP_DIR"
      done

      echo
      echo "Start processing video ..."
      files=$(ls -S "$TMP_DIR")
      while read file; do
        count=$(($count +1))
        file="$TMP_DIR/$file"
        old_video_name=$(basename "$file")
        new_video_name=$(standardized_name "$file" "MOVIE")
        if [[ $new_video_name == "NOT-MATCH"* ]]; then
          # check matching video name
          printf "${GRAY}($count) \t: %-50s -> Not match with zip file name. Ignored!${NC}\n" "$old_video_name"
          continue
        fi

        #check movie name have suffix or not
        read gsuffix < "$gsuffix_path"
        if [ -z "$gsuffix" ];then
          printf "${GRAY}($count) \t: %-50s -> Invalid suffix. Ignored!${NC}\n" "$old_video_name"
          continue;
        fi
        TOTAL_MEDIA_FILE=$(($TOTAL_MEDIA_FILE + 1))
        #check new video name existed or not
        if [[ -f "$file" ]]; then size=$(stat -c%s "$file");fi
        if list_contain "$new_video_name" "${!ARR_MOVIES[@]}";then
          #found
          printf "${RED}($count)\t: %-50s -> %s${NC}\n" "$old_video_name" "$new_video_name"
          printf "${RED}Size : $(convert_size $size) - Duplicated - Move to $DELETED_DIR)${NC}\n"
          
          # pv "$file" > "$DELETED_DIR/$(basename $file)"
          # rm -f "$file"
          mv -f "$file" "$DELETED_DIR"
          TOTAL_DEL_MEDIA_FILE=$(($TOTAL_DEL_MEDIA_FILE + 1))
          TOTAL_DEL_MEDIA_SIZE=$(($TOTAL_DEL_MEDIA_SIZE + $size))
          continue
        else
          #not found
          printf "($count) \t: %-50s -> %s\n" "$old_video_name" "$new_video_name"
          if [[ "$old_video_name" != "$new_video_name" ]];then
            mv -f "$file" "$TMP_DIR/$new_video_name" #rename video
          fi
          target_folder=$(get_target_folder ${new_video_name:0:2} $size)
          echo -e "Size\t:" "$(convert_size $size)" " - Moving to : $target_folder"
          # pv "$TMP_DIR/$new_video_name" > "$target_folder/$new_video_name"
          # rm -f "$TMP_DIR/$new_video_name"
          mv -f "$TMP_DIR/$new_video_name" "$target_folder"
          ARR_MOVIES+=(["$new_video_name"]=$size)
        fi
        echo ",,,$new_video_name,$target_folder" >> $log_path
      done <<< "$files"
    done
  fi
  rm -rf "$TMP_DIR/"
}

main(){
  local log_path="$1"
  local zip_log_path="$2"
  total=0
  if [ ! -f "$COUNTRY_FILE" ]; then
    echo "Not found country file : " $COUNTRY_FILE
    exit 1
  fi

  if [ ! -d "$LOG_DIR" ]; then
    echo "Not found log directory : " $LOG_DIR
    exit 1
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

  if [ ! -d "$AR_HOLD_DIR" ]; then printf "${YELLOW}Warning! Directory doesn't existed [AR_HOLD_DIR][$AR_HOLD_DIR]${NC}\n"; validate=1; fi
  if [ ! -d "$EN_HOLD_DIR" ]; then printf "${YELLOW}Warning! Directory doesn't existed [EN_HOLD_DIR][$EN_HOLD_DIR]${NC}\n"; validate=1; fi
  if [ ! -d "$ES_HOLD_DIR" ]; then printf "${YELLOW}Warning! Directory doesn't existed [ES_HOLD_DIR][$ES_HOLD_DIR]${NC}\n"; validate=1; fi
  if [ ! -d "$FR_HOLD_DIR" ]; then printf "${YELLOW}Warning! Directory doesn't existed [FR_HOLD_DIR][$FR_HOLD_DIR]${NC}\n"; validate=1; fi

  if [ ! -d "$DELETED_DIR" ]; then printf "${YELLOW}Warning! Directory doesn't existed [DELETED_DIR][$DELETED_DIR]${NC}\n"; validate=1; fi
  if [ ! -d "$OTHER_DIR" ]; then printf "${YELLOW}Warning! Directory doesn't existed [OTHER_DIR][$OTHER_DIR]${NC}\n"; validate=1; fi
  
  if [[ -d "$INPUT" ]]; then
    echo "Input folder : [$INPUT]"
    if [[ $mode == "TEST" ]];then
      echo "Run as check mode (-c)"
    else
      echo "Run as execute mode (-x)"
    fi
    echo
    # directory
    echo "OLD ZIP NAME,NEW ZIP NAME,ZIP SIZE,NEW VIDEO NAME,MOVED TO" > $log_path;
    echo "" > $zip_log_path;
    files=$(ls -S "$INPUT"| egrep '\.zip$|\.Zip$|\.ZIP$')
    while read file; do
      file="$INPUT/$file"
      if [ ! -f "$file" ];then continue;fi
      total=$((total+1))
      if [[ $mode == "TEST" ]];then
        check_zip_file "$file" "$log_path" "$zip_log_path" $total
      else
        process_zip_file "$file" "$log_path" "$zip_log_path" $total
      fi
      echo
    done <<< "$files"
  elif [[ -f "$INPUT" ]]; then
    # file
    if [[ $mode == "TEST" ]];then
      echo "Run as check mode (-c)"
      echo "OLD ZIP NAME,NEW ZIP NAME,ZIP SIZE,NEW VIDEO NAME" > $log_path
      echo "" > $zip_log_path;
      check_zip_file "$INPUT" "$log_path" "$zip_log_path" 1
    elif [[ $mode == "DUMMY" ]];then
      echo "Run as dummy mode(-d)"
      echo "OLD ZIP NAME|NEW ZIP NAME" > $log_path
      echo "" > $zip_log_path;
      dummy_test "$INPUT" "$log_path" "$zip_log_path"
    else
      echo "Run as execute mode(-x)"
      echo "OLD ZIP NAME,NEW ZIP NAME,ZIP SIZE,NEW VIDEO NAME" > $log_path
      echo "" > $zip_log_path;
      process_zip_file "$INPUT" "$log_path" "$zip_log_path" 1
    fi
    total=$((total+1))
  else
    echo "$INPUT is not valid"
    exit 2
  fi
  echo "=============="
  if [[ $mode == "DUMMY" ]];then
    echo "Log file info:"
    printf "%10s %-15s : $log_path \n" "-" "Full log"
    printf "%10s %-15s : $zip_log_path \n" "-" "New zip name "
  else
    echo "Log file info:"
    printf "%10s %-15s : $log_path \n" "-" "CSV log"
    printf "%10s %-15s : $zip_log_path \n" "-" "New zip name "
    printf "%10s %-15s : $full_log \n" "-" "Full log "
    echo
  fi

  echo "Zip file info:"
  printf "%10s %-15s : $total \n" "-" "Total file"
  printf "%10s %-15s : $TOTAL_NON_LANG_FILE\n" "-" "Hold file"
  printf "%10s %-15s : $TOTAL_DEL_ZIP_FILE\n" "-" "Deleted file"
  printf "%10s %-15s : %s\n" "-" "Deleted size" "$(convert_size $TOTAL_DEL_ZIP_SIZE)"
  echo
  echo "Media file info:"
  printf "%10s %-15s : $TOTAL_MEDIA_FILE\n" "-" "Total file"
  printf "%10s %-15s : $TOTAL_DEL_MEDIA_FILE\n" "-" "Deleted file"
  printf "%10s %-15s : %s\n" "-" "Deleted size" "$(convert_size $TOTAL_DEL_MEDIA_SIZE)"
  echo
  echo "Database file info:"
  printf "%10s %-15s : $DATABASE_FULL \n" "-" "Full database "
  printf "%10s %-15s : $DATABASE_AR \n" "-" "AR database "
  printf "%10s %-15s : $DATABASE_EN \n" "-" "EN database "
  printf "%10s %-15s : $DATABASE_ES \n" "-" "ES database "
  echo "Bye"
}

if [[ "$_DEBUG" != "msg" ]] && [[ "$_DEBUG" != "dbg" ]];then _DEBUG="msg"; fi

if [[ -d "$INPUT" ]]; then
  log_path="$LOG_DIR"$(echo $(basename "$INPUT")).csv
  zip_log_path="$LOG_DIR"$(echo $(basename "$INPUT"))_zip_name_only.txt
  full_log="$LOG_DIR"$(echo $(basename "$INPUT"))_full.txt
  full_log_tmp="$full_log"".tmp"
elif [[ -f "$INPUT" ]]; then
  file_name=$(echo $(basename "$INPUT"))
  log_path="$LOG_DIR"$(echo $file_name | cut -f 1 -d '.')".csv"
  zip_log_path="$LOG_DIR"$(echo $file_name | cut -f 1 -d '.')"_new_zip_name.txt"
  full_log="$LOG_DIR"$(echo $file_name | cut -f 1 -d '.')"_full.txt"
  full_log_tmp="$full_log"".tmp"
else
  echo "$INPUT is not valid"
  exit 2
fi

if [[ $timestamp == "off" ]];then
  main "$log_path" "$zip_log_path"| tee "$full_log_tmp"
else
  main "$log_path" "$zip_log_path"| while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done | tee "$full_log_tmp"
fi
sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g" "$full_log_tmp" > "$full_log"
rm -rf "$full_log_tmp"

# group zip file and video file
if [[ $mode == "RUN" ]];then
  for i in "${!TARGET_DIR_LIST[@]}";do
    create_group "${TARGET_DIR_LIST[$i]}"
  done
fi