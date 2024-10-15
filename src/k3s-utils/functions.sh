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

mount_kubelet_to_bosh_data() {
  local kubelet_default="/var/lib/kubelet"
  if [ ! -d "$kubelet_default" ]; then
    mkdir -p "$kubelet_default"
    chown -R root:root "$kubelet_default"
    chmod 775 "$kubelet_default"
  fi
  local kubelet_bosh_data="/var/vcap/data/k3s-kubelet"
  if [ ! -d "$kubelet_bosh_data" ]; then
    mkdir -p "$kubelet_bosh_data"
    chown -R root:root "$kubelet_bosh_data"
    chmod 775 "$kubelet_bosh_data"
  fi
  if ! mountpoint -q "$kubelet_default"; then
    mount --bind "$kubelet_bosh_data" "$kubelet_default"
  fi
}

wait_for_file_creation() {
  local file_path="$1"
  local timeout="${2:-120}"
  local start_time

  start_time=$(date +%s)
  while [[ ! -f "$file_path" ]]; do
    local current_time
    current_time=$(date +%s)
    local elapsed_time=$((current_time - start_time))
    if [[ $elapsed_time -ge $timeout ]]; then
      local directory
      directory=$(dirname "$file_path")
      echo "Timeout reached: The file '$file_path' still doesn't exist after $timeout seconds."
      echo "Files in the file directory $directory:"
      ls -l "$directory"
      return 1
    fi
    sleep 1
  done
  return 0
}

k3s_kubectl() {
  /var/vcap/packages/k3s/k3s kubectl --insecure-skip-tls-verify "$@" && return 0
  return 1
}

k3s_wait_for_server_healthy() {
  local kubeconfig="$1"
  local timeout="${2:-120}"
  local start_time

  start_time=$(date +%s)
  while true; do
    if k3s_kubectl --kubeconfig="$kubeconfig" get --raw='/healthz' > /dev/null 2>&1; then
      return 0
    fi
    local current_time
    current_time=$(date +%s)
    local elapsed_time=$((current_time - start_time))
    if [[ $elapsed_time -ge $timeout ]]; then
      echo "Timeout reached: Server is still unhealthy after $timeout seconds, kubeconfig: '$kubeconfig'."
      return 1
    fi
    sleep 1
  done
}

k3s_wait_for_node_ready() {
  local kubeconfig="$1"
  local node_name="$2"
  local timeout="${3:-120}"
  local start_time

  start_time=$(date +%s)
  while true; do
    if k3s_kubectl --kubeconfig="$kubeconfig" get node "$node_name" &> /dev/null; then
      sleep 10
      k3s_kubectl --kubeconfig="$kubeconfig" wait --for=condition=Ready node "$node_name" --timeout="${timeout}s"
      return 0
    fi
    local current_time
    current_time=$(date +%s)
    local elapsed_time=$((current_time - start_time))
    if [[ $elapsed_time -ge $timeout ]]; then
      echo "Timeout reached: Node '$node_name' is still NOT ready after $timeout seconds, kubeconfig: '$kubeconfig'."
      return 1
    fi
    sleep 1
  done
}

k3s_wait_for_system_pods_ready() {
  local kubeconfig="$1"
  local timeout="${2:-120}"
  local start_time

  start_time=$(date +%s)
  while true; do
    local pod_count
    pod_count=$(k3s_kubectl --kubeconfig="$kubeconfig" -n kube-system get pod -l '!batch.kubernetes.io/job-name' --no-headers 2>/dev/null | wc -l || echo 0)
    if [ "$pod_count" -gt 0 ]; then
      if k3s_kubectl --kubeconfig="$kubeconfig" wait --for=condition=Ready -n kube-system pod --all -l '!batch.kubernetes.io/job-name' --timeout="${timeout}s"; then
        return 0
      fi
    fi
    local current_time
    current_time=$(date +%s)
    local elapsed_time=$((current_time - start_time))
    if [[ $elapsed_time -ge $timeout ]]; then
      echo "Timeout reached: Pods are still NOT ready after $timeout seconds, kubeconfig: '$kubeconfig'."
      return 1
    fi
    sleep 1
  done
}


wait_for_http_service_ok() {
  local url="$1"
  local timeout="${2:-120}"
  local start_time

  start_time=$(date +%s)
  while true; do
    if curl --insecure --silent --fail "$url" > /dev/null; then
      exit 0
    fi
    local current_time
    current_time=$(date +%s)
    local elapsed_time=$((current_time - start_time))
    if [[ $elapsed_time -ge $timeout ]]; then
      echo "Timeout reached: HTTP service is still NOT ready after $timeout seconds, url: '$url'."
      return 1
    fi
    sleep 1
  done
}