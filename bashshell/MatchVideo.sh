#!/bin/bash
###################################################################
#Script Name    : MatchingVideo
#Description    : Find all video in source folder, rename file (same ZipSun rule)
#               move file to target folder
#               Rename and move file to destination folder
#Version        : 2.5
#Notes          : None
#Author         : phongtran0715@gmail.com
###################################################################

_VERSION="MatchVideoScript - 2.5"

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
TEAMS=("RT", "NG" "EG" "CT" "SH" "ST" "	")

# Neglects keyword will be remove from zip file name
NEGLECTS_KEYWORD=("V1" "V2" "V3" "V4" "SQ" "-SW-" "-NA-" "-CL-" "FYT" "FTY" "SHORT" "SQUARE" "SAKHR"
	"KHEIRA" "TAREK" "TABISH" "ZACH" "SUMMAQAH" "HAMAMOU" "ITANI" "YOMNA" "COPY" "COPIED")

# List suffix keyword in video file name
# Only process video that have this keyword in filename
SUFFIX_LISTS=("SUB" "FINAL" "CLEAN" "TW" "TWITTER" "FB" "FACEBOOK" "YT" "YOUTUBE" "IG" "INSTAGRAM")

# List prefix keyword in video file name
# Only process video that have this keyword in filename
PREFIX_LISTS=("EN-NR" "EN-CT" "AR-RT" "AJE-ONL" "AJA-DNR" "AJD-DGT" "AJB-DGT")

#  Delete file that contain this keyword in file name
DELETE_KEYWORD=("RECORD" "-VO" "-CAM" "-TAKE" "TEST")

# File name contain this kewords will not be deleted
WHITE_LIST_KEYWORD=("CAMBRIDGEXAMS" 
	"CAMPDAVIDACCORDS" 
	"WASHINGDISHESRECORD" 
	"CONFEDERATESTATUE" 
	"HOTTESTPEPPER" 
	"VOICEWHEELCHAIR" 
	"PROTEST" 
	"CAMBODIA" 
	"VOTELOCAL")

# Log folder store application running log, report log
LOG_PATH="/mnt/ajplus/Admin/"

# This  folder store deleted file
DELETED_PATH="/mnt/restore/VIDEO/_del/"

# This folder store files that need to check by manual
DELETE_FILE_THRESHOLD=$((15 * 1024 * 1024)) #15Mb
CHECK_PATH="/mnt/restore/VIDEO/_check/"

# Folder store mp4 video
MP4_PATH="/mnt/restore/VIDEO/EN-UP/"

# Folder store mov and mxf video file
MOV_MXF_PATH="/mnt/restore/VIDEO/_pre-transcode/"

# Folder store processed file and filesize > 1.5G
XL_FILE_THRESHOLD=$((15 * 1024 * 1024 * 1024 / 10)) #15Gb
PROCESSED_XL_FILE="/mnt/restore/VIDEO/_xl/"

# Folder store file that doesn't match any name
OTHER_PATH="/mnt/restore/VIDEO/_check/"

#  Report file
REPORT_FILE="$LOG_PATH/matched_video_report_"$(date +%d%m%y_%H%M)".csv"
NEW_VIDEO_NAME_FILE="$LOG_PATH/new_video_name_"$(date +%d%m%y_%H%M)".txt"

TOTAL_FILE_COUNT=0
TOTAL_SIZE_COUNT=0

MP4_FILE_COUNT=0
MP4_SIZE_COUNT=0

MXF_MOV_FILE_COUNT=0
MXF_MOV_SIZE_COUNT=0

DELETE_FILE_COUNT=0
DELETE_SIZE_COUNT=0

CHECK_FILE_COUNT=0
CHECK_SIZE_COUNT=0

gline_path="/tmp/.line_"$(date +%s)
gteam_path="/tmp/.team_"$(date +%s)
gsuffix_path="/tmp/.suffix"$(date +%s)

#This is database csv file
DATABASE_FULL="/mnt/restore/full_db.csv"
DATABASE_AR="/mnt/restore/ar_db.csv"
DATABASE_EN="/mnt/restore/en_db.csv"
DATABASE_ES="/mnt/restore/es_db.csv"

LOCK_FILE="/tmp/matchvideo.lock"

helpFunction() {
	echo ""
	echo "Script version : $_VERSION"
	echo "Usage: $0 [option] folder_path [option] language"
	echo -e "Example : ./MatchVideo.sh -c /folder1 /folder2 ..."
	echo -e "option:"
	echo -e "\t-c Run the scrip in test mode"
	echo -e "\t-x Run the script in execute mode"
	echo -e "\t-d Manual test with input text file"
	echo -e "\t-l Set language for file name"
	echo -e "\t-b Set number processing file"
	echo -e "\t-r Repeat processing job"
	exit 1
}

while getopts "d:c:x:l:b:r:" opt; do
	case "$opt" in
	d)
		INPUT="$OPTARG"
		mode="DUMMY"
		;;
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
	b)
		MAX_FILE_PROCESS=("$OPTARG")
		;;
	r)
		REPEAT_TIME=("$OPTARG")
		;;
	l) default_lang="$OPTARG" ;;
	?) helpFunction ;;
	esac
done
shift $((OPTIND - 1))

get_db_file() {
	local name="$1"
	lang=$(echo "$name" | cut -f1 -d"-")
	if [[ $lang == "AR" ]]; then
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

insert_db() {
	local old_name="$1"
	local new_name="$2"
	local size="$3"
	local path="$4"
	new_record="$1","$2","$3","$4"
	compare_str="$2","$3"
	db_children_file=$(get_db_file "$new_name")
	#create db file if ti doesn't existed
	if [ ! -f "$db_children_file" ]; then
		touch "$db_children_file"
	fi
	#insert to children
	if [ ! -z "$db_children_file" ]; then
		match=$(cat $db_children_file | grep "$compare_str")
		if [ -z "$match" ]; then
			echo "$new_record" >>"$db_children_file"
		fi
	fi

	if [ ! -f "$DATABASE_FULL" ]; then
		touch "$DATABASE_FULL"
	fi
	# insert to db parent file
	match=$(cat "$DATABASE_FULL" | grep "$compare_str")
	if [ -z "$match" ]; then
		echo "$new_record" >>"$DATABASE_FULL"
	fi
}

# convert file size to human readable
convert_size() {
	printf %s\\n $1 | LC_NUMERIC=en_US numfmt --to=iec
}

# get file size
get_file_size() {
	echo $(stat -c%s "$1")
}

# check text is suffix or not
is_suffix() {
	local data="$1"
	for i in "${!SUFFIX_LISTS[@]}"; do
		if [[ "$data" == "${SUFFIX_LISTS[$i]}" ]]; then
			return 0 #true
		fi
	done
	return 1 #false
}

# get modification of file
# if file doesn't exist -> return current date
get_modification_date() {
	local file="$1"
	file_date=$(date +'%d%m%y')
	if [ -f "$file" ]; then
		epoch_time=$(stat -c "%Y" -- "$file")
		if [ ! -z $epoch_time ]; then
			file_date=$(date -d @$epoch_time +"%d%m%y")
		fi
	fi
	echo "$file_date"
}

check_position_replace() {
	local name="$1"
	local search_str="$2"
	local replace_str="$3"
	shift
	result=$(echo $name | grep -b -o $search_str)
	if [ $? -eq 0 ]; then
		index=$(echo $result | cut -f1 -d":")
		if [ $index -eq 0 ]; then
			ofset=${#search_str}
			length=$((${#name} - $ofset))
			name=$replace_str${name:$ofset:$length}
		fi
	fi
	echo $name
}

process_episode() {
	name=$1
	match=$(echo $name | grep -oE 'S[0-9]{1,}X[0-9]{1,}')
	if [ ! -z "$match" ]; then
		name=${name/$match/"_"$match"_"}
		echo "SH-" >"$gteam_path"
	fi

	match=$(echo $name | grep -oE '[0-9]{1,}X[0-9]{1,}')
	if [ ! -z "$match" ]; then
		name=${name/$match/"_S"$match"_"}
		echo "SH-" >"$gteam_path"
	fi

	match=$(echo $name | grep -oE '_[0-9]{1,}[0-9]{1,}[0-9]{1,}' | head -n 1)
	if [ ! -z "$match" ]; then
		name=${name//$match/""}
	fi

	match=$(echo $name | grep -oE '_[0-9]{1,}' | head -n 1)
	if [ ! -z "$match" ]; then
		name=${name//$match/""}
	fi
	echo $name
}

find_raw_index() {
	index=1
	local name="$1"
	if [[ "$name" == *"."* ]]; then
		name=$(echo $name | rev | cut -d'.' -f2- | rev)
		file_name=$(find "$CHECK_PATH" -type f | sort | head -n 1 | grep "$name")
		if [ ! -z $file_name ]; then
			# remove extension
			file_name=$(echo "$file_name" | rev | cut -d'.' -f2- | rev)
			#get raw index
			index=$(echo "$file_name" | awk -FRAW '{print $NF}')
			index=$(($index + 1))
		fi
	fi
	echo $index
}

correct_desc_info() {
	local desc=$1
	result=""
	country=""
	IFS='-' read -ra arr <<<"$desc"
	#find country
	while IFS= read -r line; do
		line=$(echo ${line^^})
		for i in "${!arr[@]}"; do
			if [[ "${arr[$i]}" == "$line" ]]; then
				country=$line
				unset 'arr[$i]'
				break
			fi
		done
		if [ ! -z "$country" ]; then
			break
		fi
	done <"$COUNTRY_FILE"

	for i in "${!arr[@]}"; do
		value="${arr[$i]}"
		if [ ${#value} -lt 2 ]; then continue; fi
		result+="$value"
	done

	if [ ! -z "$country" ] && [ ! -z "$result" ]; then
		result=$country"_"$result
	else
		result="$country$result"
	fi
	# remove some keywords from description
	result=${result/"FINAL"/""}
	result=${result/"_NUMBER"/""}
	echo $result
}

remove_blacklist_keyword() {
	local name="$1"
	for i in "${NEGLECTS_KEYWORD[@]}"; do
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

order_movie_element() {
	local old_name="$1"
	local name="$2"
	local file_path="$3"
	lang=""
	team=""
	desc=""
	date=""
	#get date here
	match=$(echo $name | grep -oE '[0-9]{2}[0-9]{2}[0-9]{4}')
	if [ -z "$match" ]; then
		match=$(echo $name | grep -oE '[0-9]{2}[0-9]{2}[0-9]{2}')
		if [ ! -z "$match" ] && [ ${#match} -eq 6 ]; then
			date=$(echo $match | sed 's/[^0-9]//g')
			name=${name/"$match"/""}
		fi
	else
		if [ ${#match} -eq 8 ]; then
			date=$(echo $match | sed 's/[^0-9]//g')
			date=${date:0:4}${date:6:2}
			name=${name/"$match"/""}
		fi
	fi

	#correct date
	if [ ! -z "$date" ]; then
		dd=${date:0:2}
		mm=${date:2:2}
		yy=${date:4:2}
		if [ $mm -gt 12 ]; then date=$mm$dd$yy; fi
	fi

	IFS='-' read -ra arr <<<"$name"
	count=${#arr[@]}
	tmpSuffix=""
	previous_value=""
	for i in "${!arr[@]}"; do
		value=${arr[$i]}
		#get language
		if [ ${#value} -eq 2 ] && [[ "${LANGUAGES[@]}" =~ "$value" ]]; then
			lang=$value"-"
			previous_value=$value
			continue
		fi
		#get team, desc
		if [ ${#value} -eq 2 ] && [[ "${TEAMS[@]}" =~ $value ]]; then
			team=$value"-"
			previous_value=$value
			continue
		elif [[ $value == "VJ" ]] || [[ $value == "PL" ]]; then
			team="NG-"
			previous_value=$value
			continue
		fi
		# remove repeated character (XX)
		match=$(echo $value | grep -oE '(X)\1{1,}')
		if [ ! -z $match ]; then value=${value//"$match"/""}; fi
		# get suffix, only process suffix with movie type
		if is_suffix $value; then
			# get previous value, if previous value is team
			# this value will be description
			if [[ "${TEAMS[@]}" =~ $previous_value ]] && [ ! -z $previous_value ]; then
				desc+="$value"
			else
				# change long suffix to short suffix
				value=${value/"TWITTER"/"TW"}
				value=${value/"FACEBOOK"/"FB"}
				value=${value/"YOUTUBE"/"YT"}
				value=${value/"INSTAGRAM"/"IG"}
				tmpSuffix="$value"
			fi

		else
			if [ ! -z $value ]; then desc+="$value-"; fi
		fi
		previous_value=$value
	done
	echo "$tmpSuffix" >"$gsuffix_path"

	if [ -z "$team" ]; then team="RT-"; fi

	#remove "-" at the end of desc
	latest_desc_char= $(echo "${str: -1}")
	if [[ $latest_desc_char == "-" ]]; then
		desc=${desc:0:index}
	fi
	desc=$(correct_desc_info "$desc")

	if [ -z "$lang" ] && [ ! -z "$default_lang" ]; then
		lang="$default_lang-"
	fi

	# check case conver VJ to NG
	if [[ $team == *"NG"* ]] && [[ $name == *"-VJ-"* ]]; then
		desc="$desc"_VJ
	fi

	if [ -z "$lang" ]; then
		name="$team$desc"
	else name="$lang$team$desc"; fi

	#append date
	if [ -z $date ]; then
		date=$(get_modification_date "$file_path")
	else
		year=${date: -2}
		if [ $((year + 0)) -gt 19 ]; then
			date=$(get_modification_date "$file_path")
		fi
	fi
	name="$name-$date"
	#append suffix if type is movie
	if [ ! -z $tmpSuffix ]; then name=$name-$tmpSuffix; fi
	echo $name
}

standardized_name() {
	local file_path="$1"
	echo "" >"$gsuffix_path"
	echo "" >"$gteam_path"

	local old_name=$(basename "$file_path")
	local path=$(dirname "$file_path")
	local name=$old_name
	#Remove .extension
	if [[ "$name" == *"."* ]]; then
		ext=$(echo $name | rev | cut -d'.' -f 1 | rev)
		name=$(echo $name | rev | cut -d'.' -f2- | rev)
	fi

	# convert from UTF-8 to ASCII
	name=$(echo "$name" | iconv -f UTF-8 -t ASCII//TRANSLIT)

	#Replace space by -
	name=$(echo "$name" | sed -e "s/ /-/g")

	#Remove illegal characters
	name=$(echo $name | sed 's/[^.a-zA-Z0-9_-]//g')

	#Remove .n characters
	match=$(echo $name | grep -oE '[.][0-9]{1,}')
	if [ ! -z "$match" ]; then
		name=${name/$match/""}
	fi

	#Convert lower case to upper case
	name=$(echo ${name^^})

	#Replace invaild keyword
	name=${name/"VJDIRTY"/"_VJDIRTY"}
	name=${name/"VJ-DIRTY"/"_VJDIRTY"}
	name=${name/"VJ_DIRTY"/"_VJDIRTY"}

	name=${name/"INTVS"/"_INTVS_VJRAW"}

	name=${name/"VJMASTER"/"_VJMASTER"}
	name=${name/"VJ-MASTER"/"_VJMASTER"}
	name=${name/"VJ_MASTER"/"_VJMASTER"}

	name=${name/"VJCLEAN"/"_VJCLEAN"}
	name=${name/"VJ-CLEAN"/"_VJCLEAN"}
	name=${name/"VJ_CLEAN"/"_VJCLEAN"}

	name=${name/"VJRAW"/"_VJRAW"}
	name=${name/"VJ_RAW"/"_VJRAW"}
	name=${name/"VJ-RAW"/"_VJRAW"}

	name=${name/"_RAW_"/"_"}

	match=$(echo $name | grep -o 'SALEET')
	if [ ! -z "$match" ]; then
		name=${name/$match/""}
		echo "SH-SA_" >"$gteam_path"
	fi

	match=$(echo $name | grep -o 'REEM')
	if [ ! -z "$match" ]; then
		name=${name/$match/""}
		echo "SH-RM_" >"$gteam_path"
	fi

	match=$(echo $name | grep -oE '_[0-9]{6}')
	if [ ! -z "$match" ]; then
		new_str="-"${match:1}
		name=${name/$match/$new_str}
	fi

	for i in "${!SUFFIX_LISTS[@]}"; do
		search_str="_""${SUFFIX_LISTS[$i]}"
		replace_str="-""${SUFFIX_LISTS[$i]}"
		name=${name/$search_str/$replace_str}
	done

	#remove neglect keyword
	name=$(remove_blacklist_keyword "$name")
	if [[ $name = *_ ]]; then name=${name::-1}; fi
	if [[ $name = _* ]]; then name=${name:1}; fi

	# Extract keyword from description
	name=${name/"FINAL"/"-FINAL"}
	name=${name/"CLEAN"/"-CLEAN"}
	name=${name/"FB"/"-FB"}
	name=${name/"FACEBOOK"/"-FACEBOOK"}
	name=${name/"FB1"/"-FB"}
	name=${name/"FB2"/"-FB"}

	name=$(process_episode "$name")

	# reorder element
	name=$(order_movie_element "$old_name" "$name" "$file_path")

	# remove duplicate exe inside name
	name=${name/".MP4"/""}
	name=${name/".MOV"/""}
	name=${name/".MXF"/""}

	if [ ! -z ${ext+x} ]; then name=$name".$ext"; fi
	#Remove duplicate chracter (_, -)
	tmp_name=""
	pc=""
	for ((i = $((${#name} - 1)); i >= 0; i--)); do
		c="${name:$i:1}"
		if [[ $c == "_" ]] || [[ $c == "-" ]]; then
			if [[ $pc == "_" ]] || [[ $pc == "-" ]]; then
				continue
			else tmp_name=$c$tmp_name; fi
		else tmp_name=$c$tmp_name; fi
		pc=$c
	done
	name=$tmp_name

	name=${name/"ES-ST"/"ES-RT"}
	name=${name/"E-SH"/"ES-RT"}

	for i in "${TEAMS[@]}"; do
		name=${name/"$i""_"/"$i""-"}
	done
	echo $name
}

get_target_folder_by_ext() {
	local file="$1"
	file_ext=$(echo "$file" | rev | cut -d'.' -f 1 | rev)
	date=$(echo $(basename $file) | grep -oE '[0-9]{2}[0-9]{2}[0-9]{2}')
	if [[ $file_ext == "mp4" ]] || [[ $file_ext == "MP4" ]]; then
		result="$MP4_PATH"
		if [ ! -z $date ]; then
			year=${date: -2}
			if [ $((year + 0)) -ge 18 ]; then
				mkdir -p "$result/20"$year"/"
				result="$result/20"$year"/"
			fi
		fi
	elif [[ $file_ext == "mov" ]] || [[ $file_ext == "MOV" ]]; then
		result="$MOV_MXF_PATH"
		year=${date: -2}
		if [ $((year + 0)) -ge 18 ]; then
			mkdir -p "$result/20"$year"/"
			result="$result/20"$year"/"
		fi
	elif [[ $file_ext == "mxf" ]] || [[ $file_ext == "MXF" ]]; then
		result="$MOV_MXF_PATH"
		year=${date: -2}
		if [ $((year + 0)) -ge 18 ]; then
			mkdir -p "$result/20"$year"/"
			result="$result/20"$year"/"
		fi
	else result="$OTHER_PATH"; fi

	echo $result
}

# save new video file name to text file
save_new_video_name() {
	local new_name="$1"
	# remove extension
	new_name=$(echo "$new_name" | rev | cut -d'.' -f2- | rev)
	#remove suffix
	latest_part=$(echo "$new_name" | rev | cut -d'-' -f 1 | rev)
	remaining_part=$(echo "$new_name" | rev | cut -d'-' -f2- | rev)
	if is_suffix $latest_part; then
		echo "$remaining_part" >>"$NEW_VIDEO_NAME_FILE"
	else
		echo "$new_name" >>"$NEW_VIDEO_NAME_FILE"
	fi
}

is_contain_blacklist() {
	local file_name="$1"
	# convert lowcase to upcase
	file_name=$(echo ${file_name^^})
	for i in "${DELETE_KEYWORD[@]}"; do
		if [[ $file_name == *"$i"* ]]; then
			echo "$i" #true
			return
		fi
	done
	echo "-1" #false
}

is_contain_whitelist() {
	local file_name="$1"
	file_name=$(echo ${file_name^^})
	for i in "${WHITE_LIST_KEYWORD[@]}"; do
		if [[ $file_name == *"$i"* ]]; then
			return 0 #true
		fi
	done
	return 1 #false
}

is_contain_suffix_keyword() {
	local file_name="$1"
	file_name=$(echo ${file_name^^})
	for i in "${SUFFIX_LISTS[@]}"; do
		if [[ $file_name == *"$i"* ]]; then
			return 0 #true
		fi
	done
	return 1 #false
}

is_contain_prefix_keyword() {
	local file_name="$1"
	file_name=$(echo ${file_name^^})
	for i in "${PREFIX_LISTS[@]}"; do
		if [[ $file_name == "$i"* ]]; then
			return 0 #true
		fi
	done
	return 1 #false
}

# run test with text input file
dummy_test() {
	local file_path="$1"
	while IFS= read -r line; do
		old_name=$(echo ${line^^})
		if [ -z "$old_name" ]; then continue; fi
		echo "($TOTAL_FILE_COUNT)File: $line"
		TOTAL_FILE_COUNT=$(($TOTAL_FILE_COUNT + 1))

		# Check delete condition
		delete_keyword=$(is_contain_blacklist "$old_name")
		if [ "$delete_keyword" != "-1" ]; then
			if is_contain_whitelist "$old_name"; then
				echo " "
			else
				echo "Found deleted keyword : '$delete_keyword'"
				echo "Move to : $DELETED_PATH"
				echo "$line, - ,0, $DELETED_PATH" >>"$REPORT_FILE"
				echo
				DELETE_FILE_COUNT=$(($DELETE_FILE_COUNT + 1))
				continue
			fi
		fi

		# Check file name contain prefix keyword
		if is_contain_prefix_keyword "$old_name"; then
			echo ""
		else
			echo "File name doesn't contain valid prefix keyword'"
			echo "Move to : $OTHER_PATH"
			CHECK_FILE_COUNT=$(($CHECK_FILE_COUNT + 1))
			continue
		fi
		
		# Check file name contain suffix keyword
		if is_contain_suffix_keyword "$old_name"; then
			new_name=$(standardized_name "$old_name")
			echo "New name : $new_name"
			target_folder=$(get_target_folder_by_ext "$line")
			echo "Move to : $target_folder"
			echo "$line, $new_name,0, $target_folder" >>"$REPORT_FILE"
			save_new_video_name "$new_name"
			file_ext=$(echo "$file" | rev | cut -d'.' -f 1 | rev)
			if [[ $file_ext == "mp4" ]] || [[ $file_ext == "MP4" ]]; then
				MP4_FILE_COUNT=$((MP4_FILE_COUNT + 1))
				if [ mode == "RUN" ]; then
					MP4_SIZE_COUNT=$(($MP4_SIZE_COUNT + $size))
				fi
			elif [[ $file_ext == "mov" ]] || [[ $file_ext == "MOV" ]]; then
				MXF_MOV_FILE_COUNT=$(($MXF_MOV_FILE_COUNT + 1))
				if [ mode == "RUN" ]; then
					MXF_MOV_SIZE_COUNT=$(($MXF_MOV_SIZE_COUNT + $size))
				fi
			elif [[ $file_ext == "mxf" ]] || [[ $file_ext == "MXF" ]]; then
				MXF_MOV_FILE_COUNT=$(($MXF_MOV_FILE_COUNT + 1))
				if [ mode == "RUN" ]; then
					MXF_MOV_SIZE_COUNT=$(($MXF_MOV_SIZE_COUNT + $size))
				fi
			else
				echo
			fi
		else
			new_name=$(standardized_name "$file_path")
			RAW_FILE_COUNT=$(find_raw_index "$new_name")
			if [[ "$new_name" == *"-RAW"* ]]; then
				new_name=${new_name/"-RAW"/"-RAW"$RAW_FILE_COUNT}
			else
				ext=$(echo $new_name | rev | cut -d'.' -f 1 | rev)
				name=$(echo $new_name | rev | cut -d'.' -f2- | rev)
				new_name=$name"-RAW"$RAW_FILE_COUNT".$ext"
			fi
			echo "New name : $new_name"
			echo "Move to : $CHECK_PATH"
			echo "$line, $new_name ,0, $CHECK_PATH" >>"$REPORT_FILE"
			CHECK_FILE_COUNT=$(($CHECK_FILE_COUNT + 1))
		fi

		echo "---------------------"
		echo
	done <"$file_path"
}

# run application with input folder
process_match_video() {
	local file_path="$1"
	size=$(get_file_size "$file_path")
	old_name=$(basename "$file_path")

	# Check delete condition
	delete_keyword=$(is_contain_blacklist "$old_name")
	if [ "$delete_keyword" != "-1" ]; then
		if is_contain_whitelist "$old_name"; then
			echo " "
		else
			echo "Found deleted keyword : '$delete_keyword'"
			echo "Move to : $DELETED_PATH"
			if [[ $mode == "RUN" ]]; then
				mv -f "$file_path" "$DELETED_PATH"
			fi
			echo "$old_name, - ,$(convert_size "$size"), $DELETED_PATH" >>"$REPORT_FILE"
			echo "---------------------"
			echo
			DELETE_FILE_COUNT=$(($DELETE_FILE_COUNT + 1))
			DELETE_SIZE_COUNT=$(($DELETE_SIZE_COUNT + $size))
			return
		fi
	fi

	# Check file name contain prefix keyword
	if is_contain_prefix_keyword "$old_name"; then
		echo ""
	else
		echo "File name doesn't contain valid prefix keyword'"
		echo "Copy to : $OTHER_PATH"
		if [[ $mode == "RUN" ]]; then
			mv -f "$file_path" "$OTHER_PATH"
		fi
		CHECK_FILE_COUNT=$(($CHECK_FILE_COUNT + 1))
		CHECK_SIZE_COUNT=$(($CHECK_SIZE_COUNT + $size))
		return
	fi

	# Check file name contain valid keyword
	if is_contain_suffix_keyword "$old_name"; then
		new_name=$(standardized_name "$file_path")
		echo "New name : $new_name"
		if [[ $mode == "RUN" ]]; then
			if [[ "$(basename "$file_path")" != "$new_name" ]]; then
				mv -f "$file_path" "$(dirname "$file_path")/$new_name"
			fi

			# check file size and move to xl folder
			if [ $size -gt $XL_FILE_THRESHOLD ]; then
				echo "Copy to : $PROCESSED_XL_FILE"
				cp -f "$(dirname "$file_path")/$new_name" "$PROCESSED_XL_FILE"
			fi
		fi

		file_path="$(dirname "$file_path")/$new_name"
		target_folder=$(get_target_folder_by_ext "$file_path")
		echo "Move to : $target_folder"
		if [[ $mode == "RUN" ]]; then
			mv -f "$file_path" "$target_folder"
		fi
		echo "$old_name, $new_name,$(convert_size "$size"), $target_folder" >>"$REPORT_FILE"
		save_new_video_name "$new_name"

		file_ext=$(echo "$file" | rev | cut -d'.' -f 1 | rev)
		if [[ $file_ext == "mp4" ]] || [[ $file_ext == "MP4" ]]; then
			MP4_FILE_COUNT=$((MP4_FILE_COUNT + 1))
			MP4_SIZE_COUNT=$(($MP4_SIZE_COUNT + $size))
		elif [[ $file_ext == "mov" ]] || [[ $file_ext == "MOV" ]]; then
			MXF_MOV_FILE_COUNT=$(($MXF_MOV_FILE_COUNT + 1))
			MXF_MOV_SIZE_COUNT=$(($MXF_MOV_SIZE_COUNT + $size))
		elif [[ $file_ext == "mxf" ]] || [[ $file_ext == "MXF" ]]; then
			MXF_MOV_FILE_COUNT=$(($MXF_MOV_FILE_COUNT + 1))
			MXF_MOV_SIZE_COUNT=$(($MXF_MOV_SIZE_COUNT + $size))
		else
			echo
		fi

		# insert to database
		insert_db "$old_name" "$new_name" "$size" "$target_folder"
	else
		new_name=$(standardized_name "$file_path")
		RAW_FILE_COUNT=$(find_raw_index "$new_name")
		if [[ "$new_name" == *"-RAW"* ]]; then
			new_name=${new_name/"-RAW"/"-RAW"$RAW_FILE_COUNT}
		else
			ext=$(echo $new_name | rev | cut -d'.' -f 1 | rev)
			name=$(echo $new_name | rev | cut -d'.' -f2- | rev)
			new_name=$name"-RAW"$RAW_FILE_COUNT".$ext"
		fi
		echo "New name : $new_name"
		echo "Move to : $CHECK_PATH"
		if [[ $mode == "RUN" ]]; then
			mv -f "$file_path" "$(dirname "$file_path")/$new_name"
			file_path="$(dirname "$file_path")/$new_name"
			mv -f "$file_path" "$CHECK_PATH"
		fi
		echo "$old_name, $new_name ,$(convert_size "$size"), $CHECK_PATH" >>"$REPORT_FILE"
		CHECK_FILE_COUNT=$(($CHECK_FILE_COUNT + 1))
		CHECK_SIZE_COUNT=$(($CHECK_SIZE_COUNT + $size))
	fi
}

validate() {
	# validate argument
	validate=0
	if [ ! -d "$MP4_PATH" ]; then
		printf "${YELLOW}Warning! Directory doesn't existed [MP4_PATH][$MP4_PATH]${NC}\n"
		validate=1
	fi
	if [ ! -d "$MOV_MXF_PATH" ]; then
		printf "${YELLOW}Warning! Directory doesn't existed [MOV_MXF_PATH][$MOV_MXF_PATH]${NC}\n"
		validate=1
	fi
	if [ ! -d "$OTHER_PATH" ]; then
		printf "${YELLOW}Warning! Directory doesn't existed [OTHER_PATH][$OTHER_PATH]${NC}\n"
		validate=1
	fi
	if [ ! -d "$LOG_PATH" ]; then
		printf "${YELLOW}Warning! Directory doesn't existed [LOG_PATH][$LOG_PATH]${NC}\n"
		validate=1
	fi
	if [ ! -d "$DELETED_PATH" ]; then
		printf "${YELLOW}Warning! Directory doesn't existed [DELETED_PATH][$DELETED_PATH]${NC}\n"
		validate=1
	fi
	if [ ! -d "$CHECK_PATH" ]; then
		printf "${YELLOW}Warning! Directory doesn't existed [CHECK_PATH][$CHECK_PATH]${NC}\n"
		validate=1
	fi

	if [ ! -d "$PROCESSED_XL_FILE" ]; then
		printf "${YELLOW}Warning! Directory doesn't existed [PROCESSED_XL_FILE][$PROCESSED_XL_FILE]${NC}\n"
		validate=1
	fi
}

execute() {
	echo "Old Name, New Name, Size, Move to" >"$REPORT_FILE"
	echo "" >"$NEW_VIDEO_NAME_FILE"

	if [[ $mode == "RUN" ]]; then
		echo "Run the script in execute mode"
	elif [[ $mode == "TEST" ]]; then
		echo "Run the script in test mode (folder input)"
	elif [[ $mode == "DUMMY" ]]; then
		echo "Run the script in test mode (plain text input)"
	fi
	echo "-------------------------------"
	if [[ -f "$INPUT" ]]; then
		# Input is text file
		echo "Input text file : $INPUT"
		dummy_test "$INPUT"
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
		video_files=$(find $list_dir -type f \( -iname \*.mov -o -iname \*.mxf -o -iname \*.mp4 -o -iname \*.zip \) | head -n $MAX_FILE_PROCESS)
		while IFS= read -r file; do
			if [ ! -f "$file" ]; then
				continue
			fi
			size=$(get_file_size "$file")
			echo "($TOTAL_FILE_COUNT)File ($(convert_size $size)): $file"
			process_match_video "$file"
			echo "---------------------"
			echo
			TOTAL_FILE_COUNT=$(($TOTAL_FILE_COUNT + 1))
			TOTAL_SIZE_COUNT=$(($TOTAL_SIZE_COUNT + $size))
		done < <(printf '%s\n' "$video_files")
	fi

	rm -rf $gline_path
	rm -rf $gteam_path
	rm -rf $gsuffix_path
	echo
	echo "===================="
	printf "%10s %-15s : $TOTAL_FILE_COUNT\n" "-" "Total files"
	printf "%10s %-15s : $(convert_size $TOTAL_SIZE_COUNT)\n" "-" "Total size"
	echo
	printf "%10s %-15s : $DELETE_FILE_COUNT \n" "-" "Delete file"
	printf "%10s %-15s : $(convert_size $DELETE_SIZE_COUNT)\n" "-" "Delete size"
	echo
	printf "%10s %-15s : $CHECK_FILE_COUNT \n" "-" "Check file"
	printf "%10s %-15s : $(convert_size $CHECK_SIZE_COUNT)\n" "-" "Check size"
	echo
	printf "%10s %-15s : $MP4_FILE_COUNT \n" "-" "MP4 file"
	printf "%10s %-15s : $(convert_size $MP4_SIZE_COUNT)\n" "-" "MP4 size"
	echo
	printf "%10s %-15s : $MXF_MOV_FILE_COUNT \n" "-" "MXF/MOV file"
	printf "%10s %-15s : $(convert_size $MXF_MOV_SIZE_COUNT)\n" "-" "MXF/MOV size"
	echo
	printf "%10s %-15s : $log_file \n" "-" "Log file"
	printf "%10s %-15s : $REPORT_FILE \n" "-" "Report file"
	printf "%10s %-15s : $NEW_VIDEO_NAME_FILE \n" "-" "Video new name file"
}

is_script_running(){
	if [ -f "$LOCK_FILE" ]; then
		return 0 #true
	else
		return 1 #false
	fi
}

main() {
	# Check the script is running or not
	if is_script_running; then
		echo "Previous script is still running.Stop processing!"
		return
	fi

	echo "Script version : $_VERSION"
	if [ ! -f "$COUNTRY_FILE" ]; then
		echo "Not found country file : " $COUNTRY_FILE
		exit 1
	fi
	if [ -z "$MAX_FILE_PROCESS" ]; then
		MAX_FILE_PROCESS=100
	fi
	echo "Number processing file: $MAX_FILE_PROCESS"

	validate_code=$(validate)

	touch "$LOCK_FILE"
	if [ ! -z "$REPEAT_TIME" ]; then
		echo "Run the script in loop mode"
		while true; do
			if [ -z "$(ls -A "$MOV_MXF_PATH")" ]; then
				echo "Folder [$MOV_MXF_PATH] is empty"
				if [[ $mode == "RUN" ]]; then
					execute
				else
					echo "Repeat mode only run for execute mode (not work for testing mode)"
					break
				fi
			else
				echo "Folder [$MOV_MXF_PATH] is NOT empty"
				echo "The script will sleep in $REPEAT_TIME minute"
				# sleep
				sleep "$REPEAT_TIME"m
			fi
		done
	else
		echo "Run the script in one time mode"
		execute
	fi
	rm -rf "$LOCK_FILE"
}

log_file="$LOG_PATH/matching_video_log_"$(date +%d%m%y_%H%M)".txt"

main | while IFS= read -r line; do printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line"; done | tee "$log_file"

# remove duplicate name in file
sleep 3
if [[ -f "$NEW_VIDEO_NAME_FILE" ]]; then
	tmp_name_file="/tmp/.new_name"$(date +%s)
	sort "$NEW_VIDEO_NAME_FILE" | uniq >"$tmp_name_file"
	cat "$tmp_name_file" >"$NEW_VIDEO_NAME_FILE"
	rm -rf "$tmp_name_file"
fi

echo "Bye"
