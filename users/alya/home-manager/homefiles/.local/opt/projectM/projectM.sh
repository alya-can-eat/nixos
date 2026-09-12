set -uo pipefail
export SDL_AUDIODRIVER=pulseaudio

PRESET_PATH="/home/alya/.local/share/projectM/presets"
TEXTURE_PATH="/home/alya/.local/share/projectM/textures"

get_default_sink_name() {
  wpctl status \
    | sed -n '/Sinks:/,/Sources:/p' \
    | grep '\*' \
    | sed -E 's/^[^0-9]*[0-9]+\. *//; s/ \[vol:.*//' \
    | xargs
}

current_pid=""
current_sink=""

while true; do
  if [ -n "$current_pid" ] && ! kill -0 "$current_pid" 2>/dev/null; then
    echo "projectM was closed — stopping watcher"
    exit 0
  fi

  sink=$(get_default_sink_name)
  if [ "$sink" != "$current_sink" ] || { [ -n "$current_pid" ] && ! kill -0 "$current_pid" 2>/dev/null; }; then
    [ -n "$current_pid" ] && kill "$current_pid" 2>/dev/null
    projectMSDL -d "Monitor of $sink" -f 1 -p "$PRESET_PATH" --texturePath "$TEXTURE_PATH" -s 0 &
    current_pid=$!
    current_sink="$sink"
  fi
  sleep 2
done
