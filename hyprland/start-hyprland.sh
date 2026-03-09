#!/bin/sh
# Start Hyprland compositor on WSL2 with vkms backend
# Requires: custom kernel with vkms, seatd running, wayvnc
# Connect via TigerVNC at localhost:5900

LIBSEAT_BACKEND=seatd \
  WLR_BACKENDS=drm \
  WLR_DRM_DEVICES=/dev/dri/card0 \
  WLR_RENDERER=pixman \
  WLR_NO_HARDWARE_CURSORS=1 \
  start-hyprland
