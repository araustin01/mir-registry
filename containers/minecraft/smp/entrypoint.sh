#!/bin/bash

tmux new-session -d -s default '/minecraft/start.sh'

pid=$(pgrep -f 'start.sh' | tail -n 1)

sleep 5

tail -f /minecraft/logs/latest.log #&

# Monitor the Minecraft server process
# while kill -0 $pid 2> /dev/null; do
#   sleep 1
# done