SESSION_NAME="minecraft"

if [ -z "$TMUX" ]; then
    # Attach to tmux session
    tmux attach-session -t $SESSION_NAME || tmux new -s $SESSION_NAME reptyr -T $(pgrep -f 'start.sh' | tail -n 1)
fi