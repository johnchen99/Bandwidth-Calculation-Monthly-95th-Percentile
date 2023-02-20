#!/bin/bash

#######################################################
# Test: KL35

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

# Set the process name
process_name="dcache"

# Set the output directory and file names
output_dir="/root/bandwidth_test"
daily_file_prefix="bandwidth_$(date +%Y-%m-%d)"
daily_file="$daily_file_prefix.log"
monthly_file="95th_percentile_$(date +%Y-%m).log"

# Create the output directory if it doesn't exist
if [ ! -d "$output_dir" ]; then
  mkdir "$output_dir"
fi

# Create the daily output file if it doesn't exist
if [ ! -f "$output_dir/$daily_file" ]; then
    touch "$output_dir/$daily_file"
fi

# Function to calculate the 95th percentile from the daily output files
function calculate_95th_percentile() {
    # Get the daily bandwidth data for the current month
    daily_data=$(cat $output_dir/bandwidth_$(date +%Y-%m)*.log)

    # Get all the upload bandwidth for each day
    daily_speed=$(echo "$daily_data" |  awk '{print $2}')

    # Calculate the 95th percentile of the daily totals
    percentile=$(echo "$daily_speed" |  sort -n | awk '{all[NR] = $0} END{print all[int(NR*0.95 - 0.5)]}')

    # Get the current date and time
    current_date=$(date +%Y-%m-%d)
    current_time=$(date +%H:%M:%S)
    
    # Get the current timestamp
    timestamp=$(date +%s)

    # Check if the monthly output file exists, and create it if necessary
    if [ ! -f "$output_dir/$monthly_file" ]; then
        touch "$output_dir/$monthly_file"
    fi

    # Write the 95th percentile and the current date and time to the monthly output file
    echo "$current_date $current_time $timestamp $percentile" >> "$output_dir/$monthly_file"
}

# Calculate the bandwidth every five minutes
while true; do
    # Check if the date has changed, and create a new daily output file if necessary
    new_daily_file_prefix="bandwidth_$(date +%Y-%m-%d)"
    if [ "$new_daily_file_prefix" != "$daily_file_prefix" ]; then
        daily_file_prefix="$new_daily_file_prefix"
        daily_file="$daily_file_prefix.log"
        touch "$output_dir/$daily_file"
    fi

    # Get last 5/10 line of 10 seconds TCP and UDP upload bandwidths (KB/s)
    tcp_udp_bw=$(nethogs -t -s -a -c 10 | grep "$process_name" | tail -n 5 | awk '{sum += $2 } END {print sum/5}')

    # Get the current timestamp
    timestamp=$(date +%s)

    # Append the bandwidths and their sum to the daily output file
    echo "$timestamp $tcp_udp_bw"
    echo "$timestamp $tcp_udp_bw" >> "$output_dir/$daily_file"

    # Check if it's the first day of the month, and calculate the 95th percentile if necessary
    if [ "$(date +%d)" -eq 1 ]; then
        calculate_95th_percentile
    fi
    
    # Wait for five minutes before calculating again
    sleep 290

done
