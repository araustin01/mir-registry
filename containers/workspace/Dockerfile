FROM ubuntu:latest

# Copy specific binaries listed in the script output
COPY programs.txt /tmp/programs.txt

# Install necessary programs from the programs.txt file
RUN apt-get update && \
    while read -r path; do \
        apt-get install -y "$path"; \
    done < /tmp/programs.txt && \
    apt-get clean

COPY temp/ /

# Create a new user 'araustin' with a home directory
RUN useradd -m -s /bin/zsh araustin && \
    chown -R araustin:araustin /home/araustin
    
# Switch to the 'araustin' user
USER araustin

# Expose all ports (allow configuring firewall for container externally)
EXPOSE 0-65535

# Set the working directory
WORKDIR /home/araustin

CMD ["zsh"]