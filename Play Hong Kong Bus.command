#!/bin/zsh
cd "${0:A:h}"
if [[ -d "builds/Hong Kong Bus.app" ]]; then
  open "builds/Hong Kong Bus.app"
else
  /Applications/Godot.app/Contents/MacOS/Godot --path "$PWD"
fi
