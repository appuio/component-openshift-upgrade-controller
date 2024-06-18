#!/bin/bash
set -xeuo pipefail

version="${JOB_spec_desiredVersion_version:-}"

if [ -z "${version}" ]; then
  echo "No version defined, skipping ack"
  exit 0
fi

majorMinor=$(printf "%s" "$version" | cut -d "." -f 1,2)

ackKey=$(printf "%s" "$OVERRIDES_JSON" | jq -r --arg majorMinor "$majorMinor" '.[$majorMinor] // ""')

if [ -z "${ackKey}" ]; then
  minor=$(printf "%s" "$version" | cut -d "." -f 2)
  lastMinor=$((minor - 1))
  kubernetesMinor=$((minor + 13))
  ackKey="ack-4.${lastMinor}-kube-1.${kubernetesMinor}-api-removals-in-4.${minor}"
fi

patch=$(jq -nc --arg ackKey "$ackKey" '{ data: { $ackKey: "true" } }')

echo "Patching ConfigMap $CM_NAME in namespace $CM_NAMESPACE with '$patch'"
oc -n "$CM_NAMESPACE" patch cm "$CM_NAME" --patch "$patch" --type=merge
