#!/bin/bash
RED='\033[0;31m'
YELLOW='\033[1;33m'
GRAY='\033[1;30m'
NC='\033[0m'

COUNTRY_FILE="countries.txt"
LANGUSGES=("AR" "EN" "FR" "ES")
TEAMS=("RT", "NG" "EG" "CT" "SH" "ST")
NEGLECTS_KEYWORD=("V1" "V2" "V3" "V4" "-NA-" "FYT" "FTY" "SHORT" "SQUARE" "SAKHR"
  "KHEIRA" "TAREK" "TABISH" "ZACH" "SUMMAQAH" "HAMAMOU" "ITANI" "YOMNA" "COPY" "COPIED")
SUFFIX_LISTS=("SUB" "SUBS" "FINAL" "CLEAN" "TW" "TWITTER" "FB" "FACEBOOK" "YT" "YOUTUBE" "IG" "INSTAGRAM")
SUB_DIR_LISTS=("CUT" "EXPORT")

#This is target folder. Zip file will be moved to there  base on zip file size
#example : /home/jack/Documents/SourceCode/rename/output

#Target base path. Replace by path on your environment
BASE_DIR="/mnt/restore/S3UPLOAD"

#Target folder name. Those folder will be created automaticlly if them don't exist
AR_OVER_DIR="AR-OVER"
EN_OVER_DIR="EN-OVER"
ES_OVER_DIR="ES-OVER"
FR_OVER_DIR="FR-OVER"

AR_UNDER_DIR="AR-UNDER"
EN_UNDER_DIR="EN-UNDER"
ES_UNDER_DIR="ES-UNDER"
FR_UNDER_DIR="FR-UNDER"

AR_HOLD_DIR="AR-HOLD"
EN_HOLD_DIR="EN-HOLD"
ES_HOLD_DIR="ES-HOLD"
FR_HOLD_DIR="FR-HOLD"

OTHER_DIR="NOT-MATCH"

#Zip file size threshold
THRESHOLD=$((50 * 1024 * 1024 * 1024)) #50Gb
DELETE_THRESHOLD=$((50 * 1024 * 1024)) #50Mb

declare -A ARR_ZIPS
declare -A ARR_MOVIES

TOTAL_DEL_ZIP_FILE=0
TOTAL_DEL_ZIP_SIZE=0
TOTAL_NON_LANG_FILE=0

TOAL_MEDIA_FILE=0
TOTAL_DEL_MEDIA_FILE=0
TOTAL_DEL_MEDIA_SIZE=0

function DEBUG()
{
  [ "$_DEBUG" == "on" ] && $@ || :
}

helpFunction()
{
  echo ""
  echo "Usage: $0 [option] folder_path [option] language"
  echo -e "Example : ./rename -c /home/jack/Video -l AR"
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
 local data="$1"
  for i in "${!SUB_DIR_LISTS[@]}";do
    if [[ "$data" == *"${SUB_DIR_LISTS[$i]}"* ]];then
      return 0 #true
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
  printf %s\\n $1 | numfmt --to=iec-i
}

get_target_folder(){
  lang=$1
  size=$2
  if [ $size -gt $THRESHOLD ];then
    if [[ $lang == "AR" ]];then result="$BASE_DIR/$AR_OVER_DIR";
    elif [[ $lang == "EN" ]];then result="$BASE_DIR/$EN_OVER_DIR";
    elif [[ $lang == "ES" ]];then result="$BASE_DIR/$ES_OVER_DIR";
    elif [[ $lang == "FR" ]];then result="$BASE_DIR/$FR_OVER_DIR";
    else result="$BASE_DIR/$OTHER_DIR";fi
  else
    if [[ $lang == "AR" ]];then result="$BASE_DIR/$AR_UNDER_DIR";
    elif [[ $lang == "EN" ]];then result="$BASE_DIR/$EN_UNDER_DIR";
    elif [[ $lang == "ES" ]];then result="$BASE_DIR/$ES_UNDER_DIR";
    elif [[ $lang == "FR" ]];then result="$BASE_DIR/$FR_UNDER_DIR";
    else result="$BASE_DIR/$OTHER_DIR";fi
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
    # match=$(echo $value | grep -oE 'S[0-9]{1,}X[0-9]{2,}')
    # if [ ! -z "$match" ];then #found
    #   value=${value/"_"/"-"}
    # else
      # if [ ${#arr[$i]} -le 2 ] && [[ $value != "MM" ]] && [[ $value != "TP" ]]; then
      #   continue
      # fi
    # fi
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
  IFS='-' read -ra arr <<< "$name"
  count=${#arr[@]}
  date=""

  for i in "${!arr[@]}";do
    value=${arr[$i]}
    #get language
    if [ ${#value} -eq 2 ] && [[ "${LANGUSGES[@]}" =~ "$value" ]]; then
      lang=$value"-"
      continue
    fi
    #get date
    match=$(echo $value | grep -oE '[0-9]{2}[0-9]{2}[0-9]{4}')
    if [ -z "$match" ];then
      match=$(echo $value | grep -oE '[0-9]{2}[0-9]{2}[0-9]{2}')
      if [ ! -z "$match" ] && [ ${#value} -eq 6 ];then
          date=$value
          date=$(echo $date | sed 's/[^0-9]//g')
          continue
      fi
    else
      if [ ${#value} -eq 8 ];then
        date=$value
        date=$(echo $date | sed 's/[^0-9]//g')
        date=${date:0:4}${date:6:2}
        continue
      fi
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
  if [ ! -z $gteam ];then team=$gteam; fi

  #correct date
  if [ ! -z "$date" ];then
    dd=${date:0:2}
    mm=${date:2:2}
    yy=${date:4:2}
    if [ $mm -ge 12 ];then date=$mm$dd$yy; fi
  else
    if [[ $type == "ZIP" ]];then
      full_path=$path"/$old_name"
      epoch_time=$(stat -c "%X" -- "$full_path")
      date=$(date -d @$epoch_time +"%d%m%y")
    fi
  fi
  echo "$date" > "/tmp/.gzip_date"
  #remove "-" at the end of desc
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
  echo "$name" > "/tmp/.gzip_name"
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
  IFS='-' read -ra arr <<< "$name"
  count=${#arr[@]}
  date=""
  tmpSuffix=""
  for i in "${!arr[@]}";do
    value=${arr[$i]}
    #get language
    if [ ${#value} -eq 2 ] && [[ "${LANGUSGES[@]}" =~ "$value" ]]; then
      lang=$value"-"
      continue
    fi
    #get date
    match=$(echo $value | grep -oE '[0-9]{2}[0-9]{2}[0-9]{4}')
    if [ -z "$match" ];then
      match=$(echo $value | grep -oE '[0-9]{2}[0-9]{2}[0-9]{2}')
      if [ ! -z "$match" ] && [ ${#value} -eq 6 ];then
          date=$value
          date=$(echo $date | sed 's/[^0-9]//g')
          continue
      fi
    else
      if [ ${#value} -eq 8 ];then
        date=$value
        date=$(echo $date | sed 's/[^0-9]//g')
        date=${date:0:4}${date:6:2}
        continue
      fi
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

  if [ -z "$team" ];then team="RT-"; fi
  if [ ! -z $gteam ];then team=$gteam; fi

  #correct date
  if [ ! -z "$date" ];then
    dd=${date:0:2}
    mm=${date:2:2}
    yy=${date:4:2}
    if [ $mm -ge 12 ];then date=$mm$dd$yy; fi
  fi
  read gzip_date < "/tmp/.gzip_date"
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

  read gzip_name < "/tmp/.gzip_name"
  if [[ "$gzip_name" != *"$name"* ]] && [[ "$name" != *"$gzip_name"* ]];then
    name="$gzip_name" ;fi

  #append date
  if [ -z $date ]; then date=$(date +'%m%d%y'); fi
  name="$name-$date"
  #append suffix if type is movie
  echo "$tmpSuffix" > "/tmp/.gsuffix";
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
  name=${name/"EN-EN"/"EN-EG"}
  name=${name/"FINAL-SUBS"/"SUBS"}
  echo $name
}

standardized_name(){
  gteam=""
  echo "" > "/tmp/.gsuffix"
  local file_path="$1"
  local type="$2"
  if [[ $type == "ZIP" ]];then
    echo "" > "/tmp/.gzip_date"
    echo "" > "/tmp/.gzip_name"
  fi
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

  #Replace space by -
  name=$(echo "$name" | sed -e "s/ /-/g")
  # name=$(echo "$name" | sed -e "s/_/-/g")

  #Remove illegal characters
  name=$(echo $name | sed 's/[^.a-zA-Z0-9_-]//g')
  DEBUG echo "002 : $name"

  #Convert lower case to upper case
  name=$(echo ${name^^})
  DEBUG echo "003 : $name"

  match=$(echo $name | grep -oE 'S[0-9]{1,}X[0-9]{1,}')
  if [ -z "$match" ];then
    match=$(echo $name | grep -oE '[0-9]{1,}X[0-9]{1,}')
    if [ ! -z "$match" ];then
        new_str="S"$match
        name=${name/$match/$new_str}
        gteam="SH-"
    fi
  fi

  match=$(echo $name | grep -o 'SALEET')
  if [ ! -z "$match" ];then
    name=${name/$match/""}
    gteam="SH-SA_"
  fi

  match=$(echo $name | grep -o 'REEM')
  if [ ! -z "$match" ];then
    name=${name/$match/""}
    gteam="SH-RM_"
  fi

  match=$(echo $name | grep -oE '_[0-9]{6}')
  if [ ! -z "$match" ];then
    new_str="-"${match:1}
    name=${name/$match/$new_str}
  fi
  DEBUG echo "004 : $name"

  #remove neglect keywork
  name=$(remove_blacklist_keyword "$name")
  if [[ $name = *_ ]]; then name=${name::-1}; fi
  if [[ $name = _* ]]; then name=${name:1}; fi
  DEBUG echo "005 : $name"

  #reorder element
  if [[ $type == "MOVIE" ]];then
    name=$(order_movie_element "$old_name" "$name" "$path")
  else
    name=$(order_zip_element "$old_name" "$name" "$path")
  fi
  if [ ! -z ${ext+x} ]; then name=$name".$ext"; fi
  DEBUG echo "006 : $name"
  echo $name
}

get_hold_dir(){
  name="$1"
  result=""
  lang=$(echo $new_zip_name | cut -f1 -d"-")
    if [[ "$lang" != "$default_lang" ]]; then
      if [[ "$lang" == "AR" ]];then result="$BASE_DIR/$AR_HOLD_DIR";
      elif [[ "$lang" == "EN" ]];then result="$BASE_DIR/$EN_HOLD_DIR";
      elif [[ "$lang" == "ES" ]];then result="$BASE_DIR/$ES_HOLD_DIR";
      elif [[ "$lang" == "FR" ]];then result="$BASE_DIR/$FR_HOLD_DIR";
      else result=""; fi
    fi
  echo "$result"
}

check_zip_file(){
  declare -A ARR_MOVIES
  local file_path="$1"
  local log_path="$2"
  local index=$3
  count=1
  echo "----------"
  # check rename zip file
  old_zip_name=$(basename "$file_path")
  new_zip_name=$(standardized_name "$file_path" "ZIP")
  old_no_ext=$(echo $old_zip_name | cut -f 1 -d '.')
  new_no_ext=$(echo $new_zip_name | cut -f 1 -d '.')
  zipSize=$(stat -c%s "$file_path")
  # validate language if default lang not empty
  if [ ! -z $default_lang ];then
    hold_dir=$(get_hold_dir "$new_video_name")
    if [ ! -z "$hold_dir" ];then
      printf "${GRAY}($index) File : %-50s -> Moved to : %s${NC}\n" "$old_zip_name" "$hold_dir/"
      echo "$old_no_ext,$new_no_ext,,$hold_dir"  >> $log_path
      TOTAL_NON_LANG_FILE=$(($TOTAL_NON_LANG_FILE + 1))
      return
    fi
  fi
  # validate zip size
  if [ $zipSize -lt $DELETE_THRESHOLD ]; then
    printf "${RED}($index)Zip\t: %-50s (*Deleted* - Size : %s )${NC}\n" \
      "$old_zip_name" "$(convert_size $zipSize)"
    echo "$old_no_ext,under 50mb - deleted"  >> $log_path
    TOTAL_DEL_ZIP_FILE=$(($TOTAL_DEL_ZIP_FILE + 1))
    TOTAL_DEL_ZIP_SIZE=$(($TOTAL_DEL_ZIP_SIZE + $zipSize))
    return;
  fi
  # check new zip file existed or not
  if list_contain "$new_no_ext" "${!ARR_ZIPS[@]}";then
    #found
    printf "${RED}($index)Zip\t: %-50s -> %s (*Deleted* - Size : %s )${NC}\n" \
            "$old_zip_name" "$new_no_ext" "$(convert_size $zipSize)"
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
  echo "$old_no_ext,$new_no_ext,,$target_folder"  >> $log_path
  echo

  # Read zip content file
  tmpDirs=$(unzip -l "$file_path" "*/" | awk '/\/$/ { print $NF }')
  IFS=$'\n' read -rd '' -a dirs <<<"$tmpDirs"
  for d in "${dirs[@]}";do
    folder=$(echo $(basename "$d"))
    up_folder=$(echo ${folder^^})
    if is_subdir $up_folder;then
      echo
      echo -e "Folder\t: [" $folder "]"
      # List all file in sub folder
      tmpFiles=$(unzip -Zl "$file_path" "*/$folder/*" | rev| cut -d '/' -f 1 | rev | sort -nr)
      tmpSizes=$(unzip -Zl "$file_path" "*/$folder/*" | awk '{print $4}' | sort -nr)
      IFS=$'\n' read -rd '' -a arrFiles <<<"$tmpFiles"
      IFS=$'\n' read -rd '' -a arrSizes <<<"$tmpSizes"

      for i in "${!arrFiles[@]}";do
        old_video_name=${arrFiles[$i]}
        new_video_name=$(standardized_name "$zip_dir_name/$old_video_name" "MOVIE")
        #check movie name have suffix or not
        read gsuffix < "/tmp/.gsuffix"
        if [ -z "$gsuffix" ];then
          printf "${GRAY}($count) \t: %-50s -> Invalid suffix. Ignored!${NC}\n" "$old_video_name"
          count=$(($count +1))
          continue;
        fi
        ext="${arrFiles[$i]#*.}"
        if [[ $ext == "mp4" ]] || [[ $ext == "mxf" ]] || [[ $ext == "mov" ]];then
          TOTAL_MEDIA_FILE=$(($TOTAL_MEDIA_FILE + 1))
          #check new video name existed or not
          if list_contain "$new_video_name" "${!ARR_MOVIES[@]}";then
            #found
            printf "${RED}($count) \t: %-50s -> $new_video_name (*Deleted* - Size : %s )${NC}\n" \
            "$old_video_name" "$(convert_size ${arrSizes[$i]})"
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
          echo ",,$folder/$new_video_name,$target_folder" >> $log_path
        else
          printf "${YELLOW}($count) \t: %-50s -> Unsupport media type. Ignored!${NC}\n" "$old_video_name"
        fi
        count=$(($count +1))
      done
    fi
  done
}

process_zip_file(){
  local file_path="$1"
  local index=$2
  count=1
  echo "----------"
  # check rename zip file
  old_zip_name=$(basename "$file_path")
  new_zip_name=$(standardized_name "$file_path" "ZIP")
  old_no_ext=$(echo $old_zip_name | cut -f 1 -d '.')
  new_no_ext=$(echo $new_zip_name | cut -f 1 -d '.')
  zipSize=$(stat -c%s "$file_path")
  zip_dir_name=$(dirname "$file_path")
  # validate language if default lang not empty
  if [ ! -z $default_lang ];then
    hold_dir=$(get_hold_dir "$new_zip_name")
    if [ ! -z "$hold_dir" ];then
      printf "${YELLOW}($index) File : %-50s -> Moved to : %s${NC}\n" "$old_zip_name" "$hold_dir"
      mv -f "$zip_dir_name/$old_zip_name" "$hold_dir/"
      TOTAL_NON_LANG_FILE=$(($TOTAL_NON_LANG_FILE + 1))
      return
    fi
  fi
  # validate zip size
  if [ $zipSize -lt $DELETE_THRESHOLD ]; then
    printf "${RED}($index)Zip\t: %-50s (*Deleted* - Size : %s )${NC}\n" \
      "$old_zip_name" "$(convert_size $zipSize)"
    rm -f "$file_path";
    TOTAL_DEL_ZIP_FILE=$(($TOTAL_DEL_ZIP_FILE + 1))
    TOTAL_DEL_ZIP_SIZE=$(($TOTAL_DEL_ZIP_SIZE + $zipSize))
    return;
  fi
  # check new zip file existed or not
  if list_contain "$new_no_ext" "${!ARR_ZIPS[@]}";then
    #found
    printf "${RED}($index)Zip\t: %-50s -> %s (*Deleted* - Size : %s )${NC}\n" \
            "$old_zip_name" "$new_no_ext" "$(convert_size $zipSize)"
    rm -f $"file_path"
    TOTAL_DEL_ZIP_FILE=$(($TOTAL_DEL_ZIP_FILE + 1))
    TOTAL_DEL_ZIP_SIZE=$(($TOTAL_DEL_ZIP_SIZE + $zipSize))
    return
  else
    #not found
    printf "($index)Zip\t: %-50s  -> %-50s\n" "$old_no_ext" "$new_no_ext"
    # Rename zip file
    if [[ "$old_zip_name" != "$new_zip_name" ]];then
      mv -f "$zip_dir_name/$old_zip_name" "$zip_dir_name/$new_zip_name"
    fi
    ARR_ZIPS+=(["$new_no_ext"]=zipSize)
  fi

  # move to target folder
  target_folder=$(get_target_folder ${new_no_ext:0:2} $zipSize)
  echo -e "Size\t: " "$(convert_size $zipSize)" " - Moved to : $target_folder"
  if [ ! -f "$target_folder/$new_zip_name" ];then
    mv -f "$zip_dir_name/$new_zip_name" "$target_folder"
    count=$(($count +1))
  else
    return
  fi
  file_path="$target_folder/$new_zip_name"
  zip_dir_name=$(dirname "$file_path")
  echo

  # Read zip content file
  tmpDirs=$(unzip -l "$file_path" "*/" | awk '/\/$/ { print $NF }')
  IFS=$'\n' read -rd '' -a dirs <<<"$tmpDirs"

  for d in "${dirs[@]}";do
    folder=$(echo $(basename "$d"))
    up_folder=$(echo ${folder^^})
    if is_subdir $up_folder;then
      sub_folder+=("$folder")
    fi
  done

  if [ ${#sub_folder[@]} -gt 0 ];then
    # unzip
    rm -rf "/tmp/unzip/"
    mkdir -p "/tmp/unzip/"
    echo -e "Unziping ... "
    unzip -o "$file_path" -d "/tmp/unzip/" > "/tmp/unzip/log"
    if [ $? -ne 0 ]; then
      printf "${RED}Unzip file [$file_path] false!${NC}\n"
      echo ""
      return
    fi

    unzip_dir=$(cat "/tmp/unzip/log" | grep -m1 "creating:" | cut -d ' ' -f5-)
    for i in "${sub_folder[@]}";do
      echo
      echo -e "Folder\t: [ $i ]"
      # List all file in sub folder
      tmpFiles=$(ls -AS1 "$unzip_dir$i/")
      IFS=$'\n' read -rd '' -a arrFiles <<<"$tmpFiles"
      for k in "${arrFiles[@]}";do
        f="$unzip_dir$i/$k"
        if [ -f "$f" ]; then
          old_video_name=$(basename "$f")
          new_video_name=$(standardized_name "$f" "MOVIE")
          #check movie name have suffix or not
          read gsuffix < "/tmp/.gsuffix"
          if [ -z "$gsuffix" ];then
            printf "${GRAY}($count) \t: %-50s -> Invalid suffix. Ignored!${NC}\n" "$old_video_name"
            count=$(($count +1))
            continue;
          fi
          ext="${f#*.}"
          if [[ $ext == "mp4" ]] || [[ $ext == "mxf" ]] || [[ $ext == "mov" ]];then
            TOTAL_MEDIA_FILE=$(($TOTAL_MEDIA_FILE + 1))
            #check new video name existed or not
            size=$(stat -c%s "$f")
            if list_contain "$new_video_name" "${!ARR_MOVIES[@]}";then
              #found
              printf "${RED}($count) \t: %-50s -> $new_video_name (*Deleted* - Size : %s )${NC}\n" \
              "$old_video_name" "$(convert_size $size)"
              rm -f "$f"
              count=$(($count +1))
              TOTAL_DEL_MEDIA_FILE=$(($TOTAL_DEL_MEDIA_FILE + 1))
              TOTAL_DEL_MEDIA_SIZE=$(($TOTAL_DEL_MEDIA_SIZE + $size))
              continue
            else
              #not found
              printf "($count) \t: %-50s -> %s\n" "$old_video_name" "$new_video_name"
              if [[ "$old_video_name" != "$new_video_name" ]];then
                mv -f "$f" "$unzip_dir$i/$new_video_name"
              fi
              target_folder=$(get_target_folder ${new_video_name:0:2} $size)
              echo -e "Size\t:" "$(convert_size $size)" " - Moved to : $target_folder"
              mv -f "$unzip_dir$i/$new_video_name" "$target_folder"
              ARR_MOVIES+=(["$new_video_name"]=$size)
            fi
          else
            printf "${YELLOW}($count) \t: %-50s -> Unsupport media type. Ignored!${NC}\n" "$old_video_name"
          fi
          count=$(($count +1))
        fi
      done
    done
  fi
}

dummy(){
  echo "" > app.log
  old_name="EN-CT-EXPLAINER_STUDIO-WEDDINGS-080515"
  new_name=$(standardized_name "$old_name" "ZIP")
  printf "%-50s -> %s \n" "$old_name" "$new_name"
}

main(){
  total=0
  if [ ! -f $COUNTRY_FILE ]; then
    echo "Not found country file : " $COUNTRY_FILE
    exit 1
  fi
  validate=0
  if [ ! -d "$BASE_DIR" ]; then printf "${YELLOW}Warning! Directory doesn't existed [BASE_DIR][$BASE_DIR]${NC}\n"; validate=1; fi

  if [[ $mode == "RUN" ]]; then
    if [ $validate -eq 1 ];then 
      printf "${YELLOW}Please check your configuration!${NC}\n"
      return
    else
      if [ ! -d "$BASE_DIR/$AR_OVER_DIR" ]; then mkdir -p "$BASE_DIR/$AR_OVER_DIR";fi
      if [ ! -d "$BASE_DIR/$EN_OVER_DIR" ]; then mkdir -p "$BASE_DIR/$EN_OVER_DIR";fi
      if [ ! -d "$BASE_DIR/$ES_OVER_DIR" ]; then mkdir -p "$BASE_DIR/$ES_OVER_DIR";fi
      if [ ! -d "$BASE_DIR/$FR_OVER_DIR" ]; then mkdir -p "$BASE_DIR/$FR_OVER_DIR";fi

      if [ ! -d "$BASE_DIR/$AR_UNDER_DIR" ]; then mkdir -p "$BASE_DIR/$AR_UNDER_DIR";fi
      if [ ! -d "$BASE_DIR/$EN_UNDER_DIR" ]; then mkdir -p "$BASE_DIR/$EN_UNDER_DIR";fi
      if [ ! -d "$BASE_DIR/$ES_UNDER_DIR" ]; then mkdir -p "$BASE_DIR/$ES_UNDER_DIR";fi
      if [ ! -d "$BASE_DIR/$FR_UNDER_DIR" ]; then mkdir -p "$BASE_DIR/$FR_UNDER_DIR";fi

      if [ ! -d "$BASE_DIR/$AR_HOLD_DIR" ]; then mkdir -p "$BASE_DIR/$AR_HOLD_DIR";fi
      if [ ! -d "$BASE_DIR/$EN_HOLD_DIR" ]; then mkdir -p "$BASE_DIR/$EN_HOLD_DIR";fi
      if [ ! -d "$BASE_DIR/$ES_HOLD_DIR" ]; then mkdir -p "$BASE_DIR/$ES_HOLD_DIR";fi
      if [ ! -d "$BASE_DIR/$FR_HOLD_DIR" ]; then mkdir -p "$BASE_DIR/$FR_HOLD_DIR";fi

      if [ ! -d "BASE_DIR/$OTHER_DIR" ]; then mkdir -p "$BASE_DIR/$OTHER_DIR";fi
    fi
  fi
  
  # dummy
  # return
  if [[ -d "$INPUT" ]]; then
    # directory
    log_path=$(echo $(dirname "$INPUT"))"/"$(echo $(basename "$INPUT")).csv
    if [[ $mode == "TEST" ]];then echo "OLD ZIP NAME,NEW ZIP NAME, NEW VIDEO NAME, MOVED TO" > $log_path; fi
    files=$(ls -S "$INPUT"| egrep '\.zip$|\.Zip$|\.ZIP$')
    while read file; do
      file="$INPUT/$file"
      if [ ! -f "$file" ];then continue;fi
      total=$((total+1))
      if [[ $mode == "TEST" ]];then
        check_zip_file "$file" "$log_path" $total
      else
        process_zip_file "$file" $total
      fi
      echo
    done <<< "$files"
  elif [[ -f "$INPUT" ]]; then
    # file
    file_name=$(echo $(basename "$INPUT"))
    log_path=$(echo $(dirname "$INPUT"))"/"$(echo $file_name | cut -f 1 -d '.')".csv"
    if [[ $mode == "TEST" ]];then
      echo "OLD ZIP NAME,NEW ZIP NAME,NEW VIDEO NAME" > $log_path
      check_zip_file "$INPUT" "$log_path"
    else
      process_zip_file "$INPUT"
    fi
    total=$((total+1))
  else
    echo "$INPUT is not valid"
    exit 2
  fi
  echo "=============="
  if [[ $mode == "TEST" ]];then echo "Output file : " $log_path; fi
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
  echo "Bye"
}
gteam=""
main