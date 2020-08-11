#!/bin/bash
###################################################################
#Script Name    : MatchingVideo
#Description    : Find all video file that matched with zip file name 
#				Rename video by ZuiSun rule
#				Move video file to destination folder 
#Version        : 1.0
#Notes          : None                                             
#Author         : phongtran0715@gmail.com
###################################################################

RED='\033[0;31m'
YELLOW='\033[1;33m'
GRAY='\033[1;30m'
NC='\033[0m'

DATABASE_FULL="/mnt/restore/full_db.csv"
LOG_PATH="/mnt/ajplus/Admin"

AR_PATH="/mnt/restore/S3UPLOAD/TEMP-AR/"
EN_PATH="/mnt/restore/S3UPLOAD/TEMP-EN/"
ES_PATH="/mnt/restore/S3UPLOAD/TEMP-ES/"
FR_PATH="/mnt/restore/S3UPLOAD/TEMP-FR/"
OTHER_PATH="/mnt/restore/__CHECK/"

COUNTRY_FILE="countries.txt"
LANGUSGES=("AR" "EN" "FR" "ES")
TEAMS=("RT", "NG" "EG" "CT" "SH" "ST")
NEGLECTS_KEYWORD=("V1" "V2" "V3" "V4" "SQ" "-SW-" "-NA-" "FYT" "FTY" "SHORT" "SQUARE" "SAKHR"
  "KHEIRA" "TAREK" "TABISH" "ZACH" "SUMMAQAH" "HAMAMOU" "ITANI" "YOMNA" "COPY" "COPIED")
SUFFIX_LISTS=("SUB" "FINAL" "YT" "CLEAN" "TW" "TWITTER" "FB" "FACEBOOK" "YT" "YOUTUBE" "IG" "INSTAGRAM")

gteam_path="/tmp/.gteam"

helpFunction()
{
  echo ""
  echo "Usage: $0 [option] folder_path [option] language"
  echo -e "Example : ./MatchVideo.sh -c /folder1 /folder2 ..."
  echo -e "option:"
  echo -e "\t-c Check corrupt zip file"
  echo -e "\t-x Repair corrupt zip file"
  exit 1
}


while getopts "c:x:l:" opt
do
    case "$opt" in
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

get_target_folder(){
	lang=$1
	if [[ $lang == "AR" ]];then result="$AR_PATH";
	elif [[ $lang == "EN" ]];then result="$EN_PATH";
	elif [[ $lang == "ES" ]];then result="$ES_PATH";
	elif [[ $lang == "FR" ]];then result="$FR_PATH";
	else result="$OTHER_PATH";fi
	echo $result
}

check_matching(){
	local movie_path="$1"
	movie_file=$(basename "$movie_path")
	movie_name=$(echo "$movie_file" | cut -d'.' -f1)
	movie_ext=$(echo "$movie_file" | cut -d'.' -f2)
	arr=$(awk -F "," '{print $1}' "$DATABASE_FULL" | grep "$movie_name")
	if [ ! -z "$arr" ];then
		return 0 # match
	else
		return 1 # not match
	fi
	# while IFS= read -r file; do
	# 	old_name=$(echo "$file" | cut -d'.' -f1)
	# 	if [[ "$movie_name" =~ "$old_name" ]] || [[ "$old_name" =~ "$movie_name" ]]; then
	# 		return 0;
	# 	fi
	# done < <(printf '%s\n' "$arr")
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

	#append date
	if [ -z $date ]; then date=$(date +'%m%d%y'); fi
	name="$name-$date"
	
	#append suffix if type is movie
	if [ ! -z $tmpSuffix ];then name=$name-$tmpSuffix
	else name=$name"-RAW";fi
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

standardized_name(){
	local file_path="$1"
	echo "" > "$gteam_path"
	old_name=$(basename "$file_path")
	path=$(dirname "$file_path")
	name=$old_name
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

main(){
	total=0
	matched_count=0
	matched_size=0
	
	# validate argument
	validate=0
	if [ ! -d "$AR_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [AR_PATH][$AR_PATH]${NC}\n"; validate=1; fi
	if [ ! -d "$EN_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [EN_PATH][$EN_PATH]${NC}\n"; validate=1; fi
	if [ ! -d "$ES_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [ES_PATH][$ES_PATH]${NC}\n"; validate=1; fi
	if [ ! -d "$FR_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [FR_PATH][$FR_PATH]${NC}\n"; validate=1; fi
	if [ ! -d "$OTHER_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [OTHER_PATH][$OTHER_PATH]${NC}\n"; validate=1; fi
	if [ ! -d "$DATABASE_FULL" ]; then printf "${YELLOW}Warning! Directory doesn't existed [DATABASE_FULL][$DATABASE_FULL]${NC}\n"; validate=1; fi
	if [ ! -d "$LOG_PATH" ]; then printf "${YELLOW}Warning! Directory doesn't existed [LOG_PATH][$LOG_PATH]${NC}\n"; validate=1; fi
	
	# Find all video in folder
	list_dir=""
	for argument in "${INPUT[@]}"; do
		list_dir="${argument} $list_dir "
	done
    echo "Input directory : $list_dir"
    echo "Database file : $DATABASE_FULL"
    echo
	video_files=$(find $list_dir -type f \( -iname \*.mov -o -iname \*.mxf -o -iname \*.mp4 \))
	while IFS= read -r file; do
		if [ ! -f "$file" ];then continue;fi
		total=$((total + 1))
		size=$(get_file_size "$file")
		echo "----------"
		echo "($total)Cheking file ($(convert_size $size)): $file"
		if check_matching "$file";then
			matched_count=$((matched_count + 1))
			matched_size=$((matched_size + $size))
			# rename video
			new_name=$(standardized_name "$file")
			echo "Rename file to [$new_name]"
			if [[ $mode == "RUN" ]];then
				mv "$file" "$(basename "$file")/$new_name"
			fi
			# TODO: move video to destination folder 
			target_folder=$(get_target_folder ${new_name:0:2})
			echo "Move file to [$target_folder]"
			if [[ $mode == "RUN" ]];then
				mv "$file" "$target_folder/"
			fi
		else
			echo "Not found matched value"
		fi
	done < <(printf '%s\n' "$video_files")
	echo
	echo "===================="
   	printf "%10s %-15s : $total\n" "-" "Total files"
   	printf "%10s %-15s : $matched_count\n" "-" "Matched files"
   	printf "%10s %-15s : $(convert_size $matched_size)\n" "-" "Matched size"
   	
   	printf "%10s %-15s : $log_file \n" "-" "Log file"
   	echo Bye
}
log_file="$LOG_PATH/matching_video_log.txt"
main | while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done | tee "$log_file"