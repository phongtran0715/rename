import sys
import os
import csv
import re
import datetime
import time

input_dir="TestFolder"
output_csv = "good.csv"
country_file = "countries.txt"
row_list = []
languages = ["AR", "EN", "FR", "ES"]
teams = ["RT", "NG", "EG", "CT", "SH", "ST"]
neglects_keyword = ["XXX", "XX", "V1", "V2", "V3", "V4", "NA", "FYT", "FTY"]
today = datetime.date.today()

def order_element(name):
    lan=""
    team=""
    desc=""
    date=""
    elems = name.split("-")
    count = len(elems)
    lan = elems[0]
    date = elems[count-1]
    elems_2 = elems[1:count-1]
    #get team
    if elems[1]  not in teams:
        for it in elems_2:
          if it in teams:
              team = it
              elems_2.remove(it)
          else:
              team = "RT"
    else:
        team = elems[1]
        elems_2.remove(elems[1])

    #get description
    for it in elems_2:
        if it == "VJ":
          team = "NG"
        desc += it +"-"
    desc = desc[0:len(desc)-1]
    desc = correct_desc_info(desc)

    name = lan + "-" + team + "-" + desc + "-" + date
    return name

def remove_blacklist_keyword(name):
    for k in neglects_keyword:
        index = name.find("-"+k+"-")
        if index >= 0:
            name = name.replace("-"+k, "")
    # replace specific keywork
    if name.find("ARA-") == 0:
        name = "AR-" + name[4:]
    if name.find("ESP-") == 0:
        name = "ES-" + name[4:]
    if name.find("SPA-") == 0:
        name = "ES-" + name[4:]
    name = name.replace("-RT-60-", "-RT-")
    name = name.replace("-FB-60-", "-RT-")
    name = name.replace("-PL-", "-NG-")

    name = name.replace("-MM-", "-SH-MM_")
    name = name.replace("XEP", "X0")
    return name

def correct_desc_info(desc):
    elems = desc.split("-")
    result = None
    if not os.path.isfile(country_file):
       print("Country file path {} does not exist. Exiting...".format(country_file))
       sys.exit()
    with open(country_file) as fp:
        for line in fp:
            line = line.rstrip()
            line = line.upper()
            if(line in elems):
                elems.remove(line)
                result = line + "_"
                for it in elems:
                    result += it
                break
    if result == None:
        result = desc.replace("-", "")
    return result

def correct_date_info(name, old_name):
    value = None
    match = re.search(r'\d{2}\d{2}\d{2}', name)
    if match != None:
        value=match.group()
    else:
        match = re.search(r'\d{2}\d{2}\d{4}', name)
        if match != None:
            value=match.group()
            value=value[0:4] + value[6:8]
        else:
            pass

    c_value = value
    if value != None:
        dd=value[0:2]
        mm=value[2:4]
        yy=value[4:6]
        if(int(mm) > 12):
            c_value=mm+dd+yy

        if (name.endswith(value) == False):
            name = name.replace("-"+value,"")
            name += "-" + c_value
    else:
        # get last opened time
        time_opened = os.stat(os.path.join(input_dir, old_name)).st_atime
        timestamp_str = datetime.datetime.fromtimestamp(time_opened).strftime('%d%m%y')
        name+="-" + timestamp_str
        pass
    return name

def process_file_name(old_name):
    name = old_name
    #Remove illegal characters
    name = re.sub(r"[^.a-zA-Z0-9_-]+", '', name)
    #Remove .zip
    name = name[0:-4]
    #Convert lower case to upper case
    name = name.upper()
    match = re.search(r'(-[0-9]X[0-9][0-9]-)', name)
    if match != None:
        value=match.group()
        new_value = value[0] + "S" + value[1:]
        name = name.replace(value, new_value)

    #check date format
    name = correct_date_info(name, old_name)
    #remove neglect keywork
    name = remove_blacklist_keyword(name)
    #reorder element
    name = order_element(name)
    #appen extention
    name += ".zip"

    return name

def main():
    files = [f for f in os.listdir(input_dir) if os.path.isfile(os.path.join(input_dir, f))]
    for name in files:
        new_name = process_file_name(name)
        row_list.append([name, new_name])

if __name__ == '__main__':
    main()
    for row in row_list:
        os.rename(os.path.join(input_dir, row[0]),os.path.join(input_dir, row[1]))
    with open(output_csv, 'w') as outcsv:
        writer = csv.writer(outcsv)
        writer.writerow(["Old name", "New name"])
        writer.writerows(row_list)