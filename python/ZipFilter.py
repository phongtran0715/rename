import os
import argparse
from configparser import ConfigParser
import sqlite3_wp
import shutil


def get_args():
    global app_args
    global app_mode
    parser = argparse.ArgumentParser(description="Description for my parser")
    parser.add_argument("-c", "--check", nargs='+', help="Run the script as check mode", required=False, default="")
    parser.add_argument("-x", "--execute", help="Run the script as execute mode", required=False, default="")

    argument = parser.parse_args()
    status = False

    if argument.check:
        print("You have used '-c' or '--check' with argument: {0}".format(argument.check))
        app_mode = 'CHECK'
        app_args = argument.check
        status = True
    if argument.execute:
        print("You have used '-x' or '--execute' with argument: {0}".format(argument.execute))
        app_mode = "EXECUTE"
        app_args = argument.execute
        status = True
    if not status:
        app_mode = None
        app_args = None
        print("Maybe you want to use -h or -c or -x as arguments ?")

    return argument


def standard_name(old_name):
    new_name = None
    return new_name


if __name__ == '__main__':
    app_mode = None
    app_args = None
    get_args()
    print(app_args)
    if not app_args:
        print("Invalid input argument.")
        exit(1)

    # init parse config file
    parser = ConfigParser()
    parser.read('app.conf')
    delete_path = parser.get('global', 'DELETE_PATH')
    log_path = parser.get('global', 'LOG_PATH')

    # validate input variable
    if os.path.exists(delete_path):
        print("DELETE_PATH does not exist. Please check your configuration file!")

    if os.path.exists(log_path):
        print("LOG_PATH does not exist. Please check your configuration file!")

    # Init sqlite3 database
    db_file = 'zipfilter.db'
    if os.path.exists(db_file):
        os.remove(db_file)
    sql_conn = sqlite3_wp.SqliteWrapper(db_name=db_file)
    sql_conn.add_table('zip_data', path='TEXT', file_name='TEXT', size='INTEGER')

    # Create sqlite database contain all zip file information
    print("Building sqlite database")
    count = 1
    for item in app_args:
        print("Checking sub directory :" + item)
        for subdir, dirs, files in os.walk(item):
            for filename in files:
                filepath = subdir + os.sep + filename

                if filepath.endswith(".zip") or filepath.endswith(".ZIP"):
                    sql_conn.insert('zip_data', subdir, filename, str(os.path.getsize(filepath)))
                    count += 1

    print("Build database completed! Number zip file : " + str(count))
    print("Beginning to filter file from database")
    # Select unique zip file name
    query_cmd = "SELECT DISTINCT(file_name) FROM zip_data;"
    unique_names = sql_conn.query(query_cmd)
    for name in unique_names:
        query_cmd = "SELECT * FROM zip_data WHERE file_name = '" + name[0] + "' ORDER BY size DESC;"
        datas = sql_conn.query(query_cmd)
        for i in range(len(datas)):
            if i > 0:
                file_path = datas[i][0] + os.sep + datas[i][1]
                print("Moving file {} to {}".format(file_path, delete_path))
                # shutil.move(file_path, delete_path + os.sep + datas[i][1])


