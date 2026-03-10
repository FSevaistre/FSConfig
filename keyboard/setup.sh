#!/bin/bash
# Caps Lock -> Escape (GNOME/dconf)
dconf write /org/gnome/desktop/input-sources/xkb-options "['caps:escape']"
echo "Caps Lock remapped to Escape"
