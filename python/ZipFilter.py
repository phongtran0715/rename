import os
import argparse
import sys
from configparser import ConfigParser
from logging import handlers

import sqlite3_wp
import shutil
import pandas as pd
import logging


def get_args():
    global app_args
    global app_mode
    parser = argparse.ArgumentParser(description="Description for my parser")
    parser.add_argument("-c", "--check", nargs='+', help="Run the script as check mode", required=False, default="")
    parser.add_argument("-x", "--execute", help="Run the script as execute mode", required=False, default="")

    argument = parser.parse_args()
    status = False

    if argument.check:
        logging.info("You have used '-c' or '--check' with argument: {0}".format(argument.check))
        app_mode = 'CHECK'
        app_args = argument.check
        status = True
    if argument.execute:
        logging.info("You have used '-x' or '--execute' with argument: {0}".format(argument.execute))
        app_mode = "EXECUTE"
        app_args = argument.execute
        status = True
    if not status:
        app_mode = None
        app_args = None
        logging.info('Maybe you want to use -h or -c or -x as arguments ?')

    return argument


def sizeof_fmt(num, suffix='B'):
    for unit in ['', 'Ki', 'Mi', 'Gi', 'Ti', 'Pi', 'Ei', 'Zi']:
        if abs(num) < 1024.0:
            return "%3.1f%s%s" % (num, unit, suffix)
        num /= 1024.0
    return "%.1f%s%s" % (num, 'Yi', suffix)


class OneLineExceptionFormatter(logging.Formatter):
    def formatException(self, exc_info):
        result = super().formatException(exc_info)
        return repr(result)

    def format(self, record):
        result = super().format(record)
        if record.exc_text:
            result = result.replace("\n", "")
        return result


if __name__ == '__main__':
    app_mode = None
    app_args = None
    get_args()
    if not app_args:
        logging.error('Invalid input argument.')
        exit(1)

    # init parse config file
    parser = ConfigParser()
    parser.read('app.conf')
    delete_path = parser.get('global', 'DELETE_PATH')
    log_path = parser.get('global', 'LOG_PATH')

    # init logging
    log_file = os.path.join(log_path, 'zipfilter_log.txt')
    if os.path.exists(log_file):
        os.remove(log_file)
    log = logging.getLogger('')
    log.setLevel(logging.DEBUG)
    log_format = logging.Formatter("%(asctime)s - %(levelname)s : %(message)s", "%Y-%m-%d %H:%M:%S")

    ch = logging.StreamHandler(sys.stdout)
    ch.setFormatter(log_format)
    if log.hasHandlers():
        log.handlers.clear()
    log.addHandler(ch)

    fh = handlers.RotatingFileHandler(log_file, maxBytes=(1048576 * 5), backupCount=7, mode='w')
    fh.setFormatter(log_format)
    log.addHandler(fh)

    # validate input variable
    if not os.path.exists(delete_path):
        logging.error('DELETE_PATH does not exist. Please check your configuration file!')

    if not os.path.exists(log_path):
        logging.error('LOG_PATH does not exist. Please check your configuration file!')

    # Init sqlite3 database
    db_file = os.path.join(log_path, 'zipfilter.db')
    if os.path.exists(db_file):
        os.remove(db_file)
    sql_conn = sqlite3_wp.SqliteWrapper(db_name=db_file)
    sql_conn.add_table('zip_data', path='TEXT', file_name='TEXT', size='INTEGER')

    # Create sqlite database contain all zip file information
    logging.info('Building sqlite database')
    total_count = 0
    total_size = 0
    total_delete = 0
    total_delete_size = 0
    for item in app_args:
        logging.info('Checking sub directory :' + item)
        for subdir, dirs, files in os.walk(item):
            for filename in files:
                file_path = subdir + os.sep + filename

                if file_path.endswith(".zip") or file_path.endswith(".ZIP"):
                    sql_conn.insert('zip_data', subdir, filename, str(os.path.getsize(file_path)))
                    total_count += 1
                    total_size += os.path.getsize(file_path)
    if total_count == 0:
        logging.WARNING("Not found any zip file")
        exit(0)

    logging.info('Build database completed! Number zip file : ' + str(total_count))
    logging.info('Beginning to filter file from database')
    # Select unique zip file name
    query_cmd = "SELECT DISTINCT(file_name) FROM zip_data;"
    unique_names = sql_conn.query(query_cmd)

    out_df = pd.DataFrame()
    for name in unique_names:
        query_cmd = "SELECT * FROM zip_data WHERE file_name = '" + name[0] + "' ORDER BY size DESC;"
        datas = sql_conn.query(query_cmd)
        for i in range(len(datas)):
            file_path = datas[i][0] + os.sep + datas[i][1]
            logging.info('')
            logging.info('Processing file ({}) : {}'.format(sizeof_fmt(os.path.getsize(file_path)), file_path))
            if i == 0:
                df2 = pd.DataFrame({'Name': [datas[i][1]], 'Size': [sizeof_fmt(os.path.getsize(file_path))],
                                    'Path': [datas[i][0]], 'IsBiggest': 'Y', 'Move to': [datas[i][0]]})
            else:
                df2 = pd.DataFrame({'Name': [datas[i][1]], 'Size': [sizeof_fmt(os.path.getsize(file_path))],
                                    'Path': [datas[i][0]], 'IsBiggest': 'N', 'Move to': [delete_path]})
                logging.info('Moving file {} to {}'.format(file_path, delete_path))
                total_delete += 1
                total_delete_size += os.path.getsize(file_path)
                if app_mode == "EXECUTE":
                    shutil.move(file_path, delete_path + os.sep + datas[i][1])
            out_df = out_df.append(df2)

    csv_log = os.path.join(log_path, 'filter_zip.csv')
    out_df.to_csv(csv_log, index=False)

    # Show information
    logging.info('')
    logging.info('============================')
    logging.info('Processed file : {}'.format(total_count))
    logging.info('Processed size : {}'.format(sizeof_fmt(total_size)))
    logging.info('Deleted file : {}'.format(total_delete))
    logging.info('Deleted size : {}'.format(sizeof_fmt(total_delete_size)))
    logging.info('Log file : ' + log_file)
    logging.info('CSV log file :' + csv_log)
    logging.info('Bye')
