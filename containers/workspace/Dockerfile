FROM ubuntu:latest

# Copy specific binaries listed in the script output
COPY programs.txt /tmp/programs.txt

# Install necessary programs from the programs.txt file
RUN apt-get update && \
    while read -r path; do \
        apt-get install -y "$path"; \
    done < /tmp/programs.txt && \
    apt-get clean

# Expose all ports (allow configuring firewall for container externally)
EXPOSE 0-65535

# Set the working directory
WORKDIR /home/araustin
