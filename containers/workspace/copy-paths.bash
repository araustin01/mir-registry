#!/bin/bash

# Load environment variables from programs.env
source programs.env

# Clear any existing files to start fresh
> programs.txt

# Populate the programs.txt file with programs to install
for prog in "${PROGRAMS_TO_INSTALL[@]}"; do
  echo $prog >> programs.txt
done

# Get the current directory path
current_dir="$(pwd)"

rm -rf "$current_dir/temp"

# Copy configuration files specified in CONFIG_FILES_TO_COPY
for config_file in "${CONFIG_FILES_TO_COPY[@]}"; do
  # Check if the file exists
  if [[ -f $config_file || -d $config_file ]]; then
    # Get the base directory of the file for destination
    dest_dir="$current_dir/temp/$(dirname $config_file)/$(basename $config_file)"

    # Create the necessary directories in the destination path
    mkdir -p "$(dirname $dest_dir)"

    # Copy the file or directory to the destination path
    cp -r "$config_file" "$dest_dir"

    echo "Copied $config_file to $dest_dir"
  else
    echo "Warning: $config_file not found on host system."
  fi
done

# Optionally add more logic to handle special cases or custom paths
