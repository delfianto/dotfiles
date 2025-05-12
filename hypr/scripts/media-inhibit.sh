#!/bin/bash

playing=$(playerctl -p spotify,chromium,firefox status 2>/dev/null)

if [[ "$playing" == "Playing" ]]; then
  # Inhibit sleep if media is playing
  systemd-inhibit --why="Media is playing" sleep infinity
else
  # Allow sleep if no media is playing (this will exit the previous inhibit)
  pkill -f "systemd-inhibit --why=\"Media is playing\" sleep infinity"
fi
