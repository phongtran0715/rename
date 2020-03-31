#!/bin/bash
COUNTRY_FILE="countries.txt"

languages=("AR" "EN" "FR" "ES")
teams=("RT", "NG" "EG" "CT" "SH" "ST")
neglects_keyword=("XXX" "XX" "V1" "V2" "V3" "V4" "NA" "FYT" "FTY")
function DEBUG()
{
  [ "$_DEBUG" == "on" ] && $@ || :
}

helpFunction()
{
   echo ""
   echo "Usage: $0 [option] absolute_folder_path"
   echo -e "Example : ./rename -l /home/jack/Video"
   echo -e "option:"
   echo -e "\t-x Check rename function"
   echo -e "\t-l Apply rename function"
   exit 1 # Exit script after printing help
}

while getopts "x:l:" opt
do
   case "$opt" in
      l ) INPUT_DIR="$OPTARG"
          mode="TEST";;
      x ) INPUT_DIR="$OPTARG"
          mode="RUN";;
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Print helpFunction in case parameters are empty
if [ -z "$INPUT_DIR" ]
then
   echo "Some or all of the parameters are empty";
   helpFunction
fi

correct_desc_info(){
    local desc=$1
    shift
    result=""
    country=""
    IFS='-' read -ra arr <<< "$desc"
    while IFS= read -r line
    do
        line=$(echo ${line^^})
        if [[ "${arr[@]}" =~ "$line" ]]; then
            #found
            country+=$line
            arr=("${arr[@]/$line}")
            break
        fi
    done < "$COUNTRY_FILE"
    count=1
    for i in "${arr[@]}"
    do
        if [ ! -z "$i" ]
        then
            if [ $count -eq 1 ]
            then
                result+=$i"-"
                count+=1
            else
                result+=$i
            fi
        fi
    done
    #remove first character (_)
    first_str=${result:0:1}
    if [[ $first_str == "_" ]]; then
        if [ ! -z "$country" ]
        then
            result=$country$result
        fi
    else
        if [ ! -z "$country" ]
        then
            result=$country"_"$result
        fi
    fi
    #remove last character (-)
    last_str=${result:(-1)}
    if [[ $last_str == "-" ]]; then
        result=${result::-1}
    fi

    echo $result
}

order_element(){
    local name="$1"
    shift
    lan=""
    team=""
    desc=""
    date=""
    IFS='-' read -ra arr <<< "$name"

    count=${#arr[@]}
    lang=${arr[0]}
    date=${arr[$count-1]}
    #remove lang , date from array
    body_arr=("${arr[@]}")
    body_arr=("${body_arr[@]:1}")
    body_arr=("${body_arr[@]/$date}")

    #get team
    team=""
    if [[ ! "${teams[@]}" =~ "${arr[1]}" ]]; then
        #not found
        for i in "${!body_arr[@]}";do
            if [[ "${teams[@]}" =~ "${body_arr[$i]}" ]]; then
                team="${body_arr[$i]}"
                #remove team from body
                unset 'body_arr[$i]'
            fi
        done
    else
        team=${arr[1]}
        for i in "${!body_arr[@]}";do
            if [[ ${body_arr[i]} = $team ]];then
                unset 'body_arr[i]'
            fi
        done
    fi
    if [ -z "$team" ]
    then
        team="RT"
    fi

    #get description
    for k in "${body_arr[@]}"
    do
        if [[ "$k" == "VJ" ]];then
            team="NG"
            continue
        fi
        if [ ! -z "$k" ]
        then
            desc+=$k"-"
        fi
    done
    #remove "-" at the end of desc
    index=$((${#desc} -1))
    if [ $index -gt 0 ]
    then
        desc=${desc:0:index}
    fi
    desc=$(correct_desc_info "$desc")
    name=$lang"-"$team"-"$desc"-"$date
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
    for i in "${neglects_keyword[@]}"
    do
        result=$(echo $name | grep "\-$i\-")
        if [ ! -z "$result" ]
        then
            name=${name/"-"$i/""}
        fi
    done
    #replace some specific key
    name=$(check_position_replace "$name" "ARA-" "AR-")
    name=$(check_position_replace "$name" "ESP-" "ES-")
    name=$(check_position_replace "$name" "SPA-" "ES-")

    name=${name/"-MM-"/"-SH-MM_"}
    name=${name/"XEP"/"X0"}
    echo $name
}

correct_date_info(){
    local name="$1"
    local old_name="$2"
    shift
    value=""
    match=$(echo $name | grep -oE '[0-9]{2}[0-9]{2}[0-9]{4}')
    if [ -z "$match" ]
    then
        match=$(echo $name | grep -oE '[0-9]{2}[0-9]{2}[0-9]{2}')
        if [ ! -z "$match" ]
        then
            value=$match
        fi
    else
        new_date=${match:0:4}${match:6:2}
        name=${name/$match/$new_date}
        value=$new_date
    fi


    if [ ! -z "$value" ]
    then
        echo "$name" | grep "$value$" > /dev/null
        if [ ! $? -eq 0 ]
        then
            name=${name/$value"-"/""}

            dd=${value:0:2}
            mm=${value:2:2}
            yy=${value:4:2}
            if [ $mm -ge 12 ]
            then
                value=$mm$dd$yy
            fi
            name=$name"-"$value
        fi
    else
        full_path=$INPUT_DIR"/$old_name"
        epoch_time=$(stat -c "%X" -- "$full_path")
        date=$(date -d @$epoch_time +"%d%m%y")
        name=$name"-"$date
    fi
    echo $name
}

process_file_name(){
    local old_name="$1"
    local name=$old_name
    shift
    #Remove illegal characters
    name=$(echo $name | sed 's/[^.a-zA-Z0-9_-]//g')

    #Remove .zip
    name=${name::-4}

    #Convert lower case to upper case
    name=$(echo ${name^^})

    match=$(echo $name | grep -oE '[0-9]{1}X[0-9]{2}')
    if [ ! -z "$match" ]
    then
        new_str="S"$match
        name=${name/"-"$match"-"/"-"$new_str"-"}
    fi

    #check date format
    name=$(correct_date_info "$name" "$old_name")

    #remove neglect keywork
    name=$(remove_blacklist_keyword "$name")

    #reorder element
    name=$(order_element "$name")
    # order_element "$name"
    name=$name".zip"
    echo $name
}

main(){
    if [ ! -d "$INPUT_DIR" ]; then
        echo "Directory $INPUT_DIR DOES NOT exists."
        exit 1
    fi

    if [ ! -f "$COUNTRY_FILE" ]; then
        echo "File $COUNTRY_FILE DOES NOT exists."
        exit 1
    fi

    folder=$(echo "$INPUT_DIR" | rev | cut -d'/' -f 1 | rev)
    output_name=$folder"_rename_info.csv"
    output_path="$(dirname "$INPUT_DIR")/$output_name"
    if [[ $mode == "TEST" ]];then
        echo "OLD NAME,NEW NAME" > $output_path
    fi
    count=1
    for f in $INPUT_DIR/*; do
        if [ -f "$f" ]; then
            old_name=$(basename -- "$f")
            new_name=$(process_file_name "$old_name")
            if [[ $mode == "RUN" ]]; then
                echo "Rename ("$count") : " "$old_name" " -> " "$new_name"
                mv -f "$INPUT_DIR/$old_name" "$INPUT_DIR/$new_name" > /dev/null
            else
                echo "Check ("$count") : " "$old_name" " -> " "$new_name"
                echo "$old_name,$new_name" >> $output_path
            fi
            count=$(($count +1))
        fi
    done
    echo "=============="
    if [[ $mode == "TEST" ]];then
        echo "Output file : " $output_path
    fi
    echo "Bye"
}

main