#!/bin/sh
#
# File jstatd; run virtual machine jstat daemon on a host

EXEC='jstatd'
HOST="${HOST:-localhost}"
PORT="${PORT:-9090}"

# Bail out if jstatd is not in PATH
if [[ -z "$(command -v ${EXEC})" ]]; then
  echo "${EXEC} is not found in your system PATH"
  exit 1
fi

POLICY=${HOME}/config/jstatd.all.policy

[[ -r ${POLICY} ]] || cat >${POLICY} <<'POLICY'
grant codebase "file:${java.home}/lib/tools.jar" {
permission java.security.AllPermission;
};
POLICY

"${EXEC}" \
  -Djava.rmi.server.logCalltrue \
  -Djava.rmi.server.hostname="${HOST}" \
  -Djava.security.policy="${POLICY}" \
  -p "${PORT}"
