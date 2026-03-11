#!/bin/bash

# Ensure log file exists so tail doesn't fail
mkdir -p logs
touch logs/latest.log

# Start the server in a detached tmux session
tmux new-session -d -s default '/minecraft/start.sh'

# Give it a moment to start
sleep 1

# Get the PID of the process running in the tmux pane (which will be Java due to 'exec' in start.sh)
PID=$(tmux list-panes -t default -F "#{pane_pid}")

if [ -z "$PID" ]; then
  echo "Error: Could not determine server PID. Tmux session may have failed."
  exit 1
fi

echo "Minecraft server started with PID $PID. Tailing logs..."

# Tail the logs to stdout so they show up in Kubernetes logs
tail -F logs/latest.log &
TAIL_PID=$!

# Monitor the Java process. If it dies, the loop ends.
while kill -0 $PID 2> /dev/null; do
  sleep 5
done

# If we are here, the server has stopped.
echo "Server process $PID exited."

# Kill the tail process so the container can exit cleanly
kill $TAIL_PID
exit 0