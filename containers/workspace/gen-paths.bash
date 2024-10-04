#!/bin/bash

source programs.env

# Create a file to store paths
> program_paths.txt
> programs.txt

for prog in "${PROGRAMS_TO_INSTALL[@]}"; do
  echo $prog >> programs.txt
done

# Use 'whereis' to find the relevant paths for each program
for prog in "${PROGRAMS_TO_INSTALL[@]}"; do
  # Get program binary paths
  paths=$(whereis -b $prog | awk '{print $2}')
  
  # If there are any binary paths, save them to the file
  if [[ ! -z $paths ]]; then
    echo "Copying binaries for $prog:"
    echo $paths
    echo $paths >> program_paths.txt
  fi
done

# Optionally find configuration files in /etc if needed
for prog in "${PROGRAMS_TO_INSTALL[@]}"; do
  config_path="/etc/$prog"
  if [[ -d $config_path ]]; then
    echo "Copying configuration for $prog:"
    echo $config_path
    echo $config_path >> program_paths.txt
  fi
done
