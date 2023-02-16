#!/bin/bash

# Set the process name
process_name="your_process_name"

# Set the output directory and file names
output_dir="bandwidth"
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
    daily_data=$(cat "$output_dir/bandwidth_$(date +%Y-%m)*.log")

    # Calculate the total upload bandwidth for each day
    daily_totals=$(echo "$daily_data" | awk '{print $1, $4}' | sort | uniq -c | awk '{print $2, $3}')

    # Calculate the 95th percentile of the daily totals
    percentile=$(echo "$daily_totals" | sort -k2n | awk '{s+=$2}END{print int(s*0.95)}')

    # Get the current date and time
    current_date=$(date +%Y-%m-%d)
    current_time=$(date +%H:%M:%S)

    # Check if the monthly output file exists, and create it if necessary
    if [ ! -f "$output_dir/$monthly_file" ]; then
        touch "$output_dir/$monthly_file"
    fi

    # Write the 95th percentile and the current date and time to the monthly output file
    echo "$current_date $current_time $percentile" >> "$output_dir/$monthly_file"
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

    # Get the TCP and UDP upload bandwidths for the process using nethogs
    tcp_bw=$(nethogs -t -s -a "$process_name" | tail -n 1 | awk '{print $2}')
    udp_bw=$(nethogs -u -s -a "$process_name" | tail -n 1 | awk '{print $2}')

    # Get the current timestamp
    timestamp=$(date +%s)

    # Append the bandwidths and their sum to the daily output file
    echo "$timestamp $tcp_bw $udp_bw $((tcp_bw + udp_bw))" >> "$output_dir/$daily_file"

    # Check if it's the first day of the month, and calculate the 95th percentile if necessary
    if [ "$(date +%d)" -eq 1 ]; then
        calculate_95th_percentile
    fi

    # Wait for five minutes before calculating again
    sleep 300
done
