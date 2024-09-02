FROM openjdk:21-jdk-slim-bookworm

# Install tmux
RUN apt-get update && \
    apt-get install -y tmux && \
    apt-get clean

# Set the working directory
WORKDIR /minecraft

ENTRYPOINT ["tmux", "new-session", "-s", "default", "./start.sh"]