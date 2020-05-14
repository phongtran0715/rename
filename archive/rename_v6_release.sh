#!/bin/bash
COUNTRY_FILE="countries.txt"

languages=("AR" "EN" "FR" "ES")
teams=("RT", "NG" "EG" "CT" "SH" "ST")
neglects_keyword=("V1" "V2" "V3" "V4" "-NA-" "FYT" "FTY" "SHORT" "SQUARE" "SAKHR"
  "KHEIRA" "TAREK" "TABISH" "ZACH" "SUMMAQAH" "HAMAMOU" "ITANI" "YOMNA" "COPY" "COPIED")
input_type=0 # 0: file / 1: folder
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

correct_desc_info(){
  local desc=$1
  result=""
  country=""
  desc=${desc/"_"/"-"}
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
    match=$(echo $value | grep -oE 'S[0-9]{1,}X[0-9]{2,}')
    if [ ! -z "$match" ];then
      value=${value/$match/"_"$match"_"}
    else
      if [ ${#arr[$i]} -le 2 ] && [[ $value != "MM" ]] && [[ $value != "TP" ]]; then
        continue
      fi
    fi
    result+="$value"
  done

  if [ ! -z "$country" ] && [ ! -z "$result" ];then
    result=$country"_"$result
  else
    result="$country$result"
  fi

  echo $result
}

order_element(){
  local old_name="$1"
  local name="$2"
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
    if [ ${#value} -eq 2 ] && [[ "${languages[@]}" =~ "$value" ]]; then
      lang=$value
      continue
    fi
    #TODO : check date with 5 digits
    #get date
    match=$(echo $value | grep -oE '[0-9]{2}[0-9]{2}[0-9]{4}')
    if [ -z "$match" ];then
      match=$(echo $value | grep -oE '[0-9]{2}[0-9]{2}[0-9]{2}')
      if [ ! -z "$match" ];then
          date=$value
          date=$(echo $date | sed 's/[^0-9]//g')
          continue
      fi
    else
      date=$value
      date=$(echo $date | sed 's/[^0-9]//g')
      date=${date:0:4}${date:6:2}
      continue
    fi
    #get team, desc
    if [ ${#value} -eq 2 ] && [[ "${teams[@]}" =~ $value ]]; then
      team=$value
      continue
    elif [[ $value == "VJ" ]] || [[ $value == "PL" ]];then
      team="NG"
      continue
    fi
    # remove repeated character (XX)
    match=$(echo $value | grep -oE '(X)\1{1,}')
    if [ ! -z $match ];then
      value=${value//"$match"/""}
    fi

    if [ ! -z $value ];then
      desc+="$value-"
    fi
  done

  if [ -z "$team" ];then
      team="RT"
  fi
  if [ ! -z $gteam ];then
    team=$gteam
  fi

  #correct date
  if [ ! -z "$date" ];then
    dd=${date:0:2}
    mm=${date:2:2}
    yy=${date:4:2}
    if [ $mm -ge 12 ];then
      date=$mm$dd$yy
    fi
  else
    if [ $input_type -eq 1 ]; then
      #get last time file accessed
      full_path=$INPUT"/$old_name"
      epoch_time=$(stat -c "%X" -- "$full_path")
      date=$(date -d @$epoch_time +"%d%m%y")
    else
      date="000000"
    fi
  fi
  #remove "-" at the end of desc
  index=$((${#desc} -1))
  if [ $index -gt 0 ];then
    desc=${desc:0:index}
  fi
  desc=$(correct_desc_info "$desc")
  echo "lang = " $lang >> app.log
  echo "default lang = " $default_lang >> app.log
  if [ -z "$lang" ] && [ ! -z "$default_lang" ];then
    lang="$default_lang"
  fi
  if [ -z "$lang" ];then
    name="$team"-"$desc"-"$date"
  else
    name="$lang"-"$team"-"$desc"-"$date"
  fi
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
  for i in "${neglects_keyword[@]}";do
    name=${name//"$i"/""}
  done
  #replace some specific key
  name=$(check_position_replace "$name" "ARA-" "AR-")
  name=$(check_position_replace "$name" "ESP-" "ES-")
  name=$(check_position_replace "$name" "SPA-" "ES-")

  name=${name/"XEP"/"X0"}
  name=${name/"RT-60"/"RT"}
  name=${name/"EN-EN"/"EN-EG"}
  echo $name
}

process_file_name(){
  gteam=""
  local old_name="$1"
  local name=$old_name
  #Remove .extension
  if [[ "$name" == *"."* ]]; then
    ext=$(echo $name | cut -d '.' -f2-)
    name=$(echo $name | cut -d '.' -f 1)
  fi
  DEBUG echo "001 : $name"

  #Replace space by -
  name=$(echo "$name" | sed -e "s/ /-/g")
  DEBUG echo "001-1 : $name"
  name=$(echo "$name" | sed -e "s/_/-/g")
  DEBUG echo "001-2 : $name"

  #Remove illegal characters
  name=$(echo $name | sed 's/[^.a-zA-Z0-9_-]//g')
  DEBUG echo "002 : $name"

  #Convert lower case to upper case
  name=$(echo ${name^^})
  DEBUG echo "003 : $name"

  match=$(echo $name | grep -oE '[0-9]{1,}X[0-9]{2,}')
  if [ ! -z "$match" ];then
      new_str="S"$match
      name=${name/$match/$new_str}
      gteam="SH"
  fi

  match=$(echo $name | grep -oE '_[0-9]{6}')
  if [ ! -z "$match" ];then
    new_str="-"${match:1}
    name=${name/$match/$new_str}
  fi
  DEBUG echo "004 : $name"

  #remove neglect keywork
  name=$(remove_blacklist_keyword "$name")
  DEBUG echo "005 : $name"

  #reorder element
  name=$(order_element "$old_name" "$name")
  if [ ! -z ${ext+x} ]; then
    name=$name".$ext"
  fi
  DEBUG echo "006 : $name"
  echo $name
}

process_file(){
  count=1
  if [[ "$INPUT" == *"."* ]]; then
    filename=$(echo $(basename "$INPUT") | cut -f 1 -d '.')
  else
    filename=$(echo $(basename "INPUT"))
  fi
  output_path="$(dirname "$INPUT")/$filename"".csv"
  if [[ $mode == "TEST" ]];then
    echo "OLD NAME,NEW NAME" > $output_path
  fi

  while IFS= read -r line
  do
    if [ -z "$line" ];then
      continue
    fi
    old_name="$line"
    new_name=$(process_file_name "$old_name")
    echo "Check ("$count") : " "$old_name" " -> " "$new_name"
    echo "$old_name,$new_name" >> $output_path
    count=$(($count +1))
  done < "$INPUT"
}

process_folder(){
  count=1
  parent_dir=$(dirname "$INPUT")
  base_name=$(basename "$INPUT")
  output_path=$parent_dir/$base_name.csv
  if [[ $mode == "TEST" ]];then
    echo "OLD NAME,NEW NAME" > $output_path
  fi

  for f in $INPUT/*; do
    if [ -f "$f" ]; then
      old_name=$(basename -- "$f")
      new_name=$(process_file_name "$old_name")
      old_file="$INPUT/$old_name"
      new_file="$INPUT/$new_name"
      if [ -f "$new_file" ];then
        existed_file_size=$(stat -c%s "$new_file")
        file_size=$(stat -c%s "$old_file")
        if [ $file_size -gt $existed_file_size ];then
          if [[ $mode == "RUN" ]]; then
            rm -f "$new_file"
            mv -f "$old_file" "$new_file" > /dev/null
          fi
          echo "*** deleted *** file : $new_file - Size : $((file_size / 1024 / 1024))  Mb"
        elif [ $file_size -lt $existed_file_size ];then
          if [[ $mode == "RUN" ]]; then
            rm -f "$old_file"
          fi
          echo "*** deleted *** file : $old_file - Size : $((file_size / 1024 / 1024))  Mb"
        else
          if [[ "$old_name" != "$new_name" ]];then
            mv -f "$old_file" "$new_file" > /dev/null
          fi
        fi
      else
        if [[ $mode == "RUN" ]]; then
          mv -f "$old_file" "$new_file" > /dev/null
        fi
      fi

      if [[ $mode == "TEST" ]]; then
          # Remove extention from file name
          if [[ "$old_name" == *"."* ]]; then
            old_name=$(echo $old_name | cut -d '.' -f 1)
            new_name=$(echo $new_name | cut -d '.' -f 1)
          fi
          echo "Check ("$count") : " "$old_name" " -> " "$new_name"
          echo "$old_name,$new_name" >> $output_path
      else
        echo "Rename ("$count") : " "$old_name" " -> " "$new_name"
      fi
      count=$(($count +1))
    fi
  done
}

dummy(){
  echo "" > app.log
  old_name="ES-RT-ARGENTINA-ARROZCONLECHE-200718.zip"
  echo "Old name : $old_name"
  process_file_name "$old_name"
}

main(){
  if [ ! -f "$COUNTRY_FILE" ]; then
    echo "File $COUNTRY_FILE DOES NOT exists."
    exit 1
  fi
  if [[ -d $INPUT ]]; then
    echo "$INPUT is a directory"
    input_type=1
    process_folder
  elif [[ -f $INPUT ]]; then
    echo "$INPUT is a file"
    input_type=0
    process_file
  else
    echo "$INPUT is not valid"
    exit 1
  fi
  # dummy
  echo "=============="
  if [[ $mode == "TEST" ]];then
      echo "Output file : " $output_path
  fi
  echo "Bye"
}
gteam=""
main