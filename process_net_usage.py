#######################################################
# sudo yum update
# yum install python36
# yum update python-devel
# yum install python36-devel
# easy_install-3.6 pip
# pip3 install  numpy

## Install Nethogs:
# yum install centos-release-scl
# yum install centos-release-scl-rh
# yum install devtoolset-10-gcc.x86_64 && yum install devtoolset-10-gcc-c++.x86_64
# scl enable devtoolset-10 bash
# yum install gcc-c++ libpcap-devel.x86_64 libpcap.x86_64 "ncurses*"
# git clone https://github.com/raboof/nethogs
# make
# sudo ./src/nethogs
# sudo make install
# hash -r
# sudo nethogs
#######################################################
import os
import time
import sys
import numpy as np
import subprocess
import logging

# Constants
PROCESS_NAME_LIST = ["dcache", "css"]
DIR = "/root/bandwidth_calc"
DAILY_DIR = os.path.join(DIR, "daily")
MONTHLY_DIR = os.path.join(DIR, "monthly")
INTERVAL = 300
# Nethogs command (MB)
NETHOGS_START_COMMAND = 'nethogs -v 3 -t -a | grep --line-buffered {} | cut -f 2-3 &> {}/$(date +"%Y-%m-%d")_{}_temp &'


# Check if DIR exists, else create
def create_directory(path):
    if not os.path.isdir(path):
        try:
            os.makedirs(path)
        except OSError as e:
            logging.error(("Error creating directory {}: {}").format(path, e))
            sys.exit(1)

# Start nethogs for process lists
def start_nethogs():
    for process_name in PROCESS_NAME_LIST:     
        # Check if process name is available
        if subprocess.check_output(('pgrep {}').format(process_name), shell=True):
            print("Spawning nethogs for: "+process_name)
            subprocess.Popen((NETHOGS_START_COMMAND.format(process_name, DAILY_DIR, process_name)), shell=True)
    
# Kill all nethogs
def kill_nethogs():  
    subprocess.run(('pkill -f "nethogs"'), shell=True)
    print("Killing all nethogs")

# Record the daily total sent traffic every 5 minutes
def record_traffic():
    while True:
        # Current time
        now = time.time()

        # Calculate the time until the next 5 minute 
        sleep_time = INTERVAL - now % INTERVAL

        # Sleep until the next 5 minute 
        time.sleep(sleep_time)

        # Current Date
        today_date = time.strftime('%Y-%m-%d')
        
        # Terminate nethogs  
        kill_nethogs()
        time.sleep(1)

        # Record the daily total sent traffic for each process
        for process_name in PROCESS_NAME_LIST:
            log_file = os.path.join(DAILY_DIR, "{}_{}_temp".format(today_date,process_name))
            if os.path.exists(log_file):
                last_log_line = ""
                with open(log_file, 'r') as f:
                    for line in f:
                        pass
                    try:
                        last_log_line = line
                    except Exception:
                        last_log_line = ""

                    with open(os.path.join(DAILY_DIR, "{}_{}_daily_traffic".format(today_date,process_name)), "a") as f:
                        f.write(("{} {}\n").format(time.strftime('%Y-%m-%d %H:%M:%S'),last_log_line))                 

        # Restart nethogs
        try:
            start_nethogs()
            print ("2. Spawned initial nethogs")

        except subprocess.CalledProcessError as e:
            logging.error(("2. Error launching nethogs: {}").format(e))

def main():
    # Set up logging
    logging.basicConfig(filename=os.path.join(DIR, "python_log.txt"), level=logging.ERROR)

    # Create directories
    create_directory(DIR)
    create_directory(DAILY_DIR)
    create_directory(MONTHLY_DIR)

    try:
        start_nethogs()
        print ("1. Spawned initial nethogs")

    except subprocess.CalledProcessError as e:
        logging.error(("1. Error launching nethogs: {}").format(e))


if __name__ == '__main__':
    try:
        main()
        # Record traffic
        record_traffic()
        
    except KeyboardInterrupt:
        # Terminate nethogs subprocesses
        kill_nethogs()
        sys.exit(0)

    except Exception as e:
        logging.error("Error running program: {}".format(e))
        kill_nethogs()
        sys.exit(0)

