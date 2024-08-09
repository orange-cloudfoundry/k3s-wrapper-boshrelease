assert_declared_functions() {
  for func in "$@"; do
    if ! declare -f "$func" > /dev/null; then
      echo "Error: function $func is not declared!"
      exit 1
    fi
  done
}

disable_ni_hardware_option() {
  local OPTION=$1
  if [ "${OPTION}" != "" ] ; then
    serviceFile="ethtool-patch-${INTERFACE}-${OPTION}.service"
    cat > "/etc/systemd/system/${serviceFile}" << EOF
[Unit]
Description=Turn off ${OPTION} on ${INTERFACE}
After=network.target
[Install]
WantedBy=multi-user.target
[Service]
Type=oneshot
ExecStart=/sbin/ethtool -K ${INTERFACE} ${OPTION} off
EOF
    #--- Start service
    /usr/bin/systemctl enable "${serviceFile}"
    /usr/bin/systemctl start "${serviceFile}"
  fi
}


k3s_check_config() {
  output=$(/var/vcap/packages/k3s/k3s check-config 2>&1)
  exit_code=$?
  # remove colors
  output=$(echo -e "$output" | sed -r 's/\x1b\[[0-9;]*m//g')
  echo -e "$output"
  if [ $exit_code -eq 0 ] && echo "$output" | tail -n 1 | grep -q "STATUS: pass"; then
    return 0
  else
    return 1
  fi
}

normalize_path() {
  echo "$1" | sed -E 's:/+:/:g' | sed -E 's:(.+)/$:\1:'
}

force_link_dir() {
  local DIR_PATH
  DIR_PATH=$(normalize_path "$1")
  local LINK_PATH
  LINK_PATH=$(normalize_path "$2")
  if [ "$LINK_PATH" = "$DIR_PATH" ]; then
    echo "The directory \"$DIR_PATH\" is the same as the link \"$LINK_PATH\""
    return 1
  else
    mkdir -p "$DIR_PATH"
    if [ -d "$LINK_PATH" ] && [ ! -L "$LINK_PATH" ]; then
      # dist dir exists, remove it
      rm -rf "$LINK_PATH"
    fi
    if [ ! -L "$LINK_PATH" ]; then
      # link doesn't exist
      ln -sf "$DIR_PATH" "$LINK_PATH"
    else
      # link exists
      actual_target=$(readlink -f "$LINK_PATH")
      if [ "$actual_target" != "$DIR_PATH" ]; then
        rm -f "$LINK_PATH"
        ln -sf "$DIR_PATH" "$LINK_PATH"
      fi
    fi
  fi
  return 0
}