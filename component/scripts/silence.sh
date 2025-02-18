#!/bin/bash
set -xeuo pipefail

job_name="$JOB_metadata_name"

if [ "${EVENT_name}" = "\"MachineConfigPoolUnpause\"" ] && [ "${EVENT_reason}" = "\"Completed\"" ]; then
  echo "Not creating a new silence when unpausing MCPs due to timeout"
  exit 0
fi

curl_opts=( "https://${ALERTMANAGER_HOST}.${ALERTMANAGER_NAMESPACE}.svc.cluster.local:9095/api/v2/silences" --cacert /etc/ssl/certs/serving-certs/service-ca.crt --header 'Content-Type: application/json' --header "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" --resolve "${ALERTMANAGER_HOST}.${ALERTMANAGER_NAMESPACE}.svc.cluster.local:9095:$(getent hosts "${ALERTMANAGER_OPERATED_SERVICE}.${ALERTMANAGER_NAMESPACE}.svc.cluster.local" | awk '{print $1}' | head -n 1)" --silent )

startsAt="$(date -u +'%Y-%m-%dT%H:%M:%S' --date '-5 minutes')"
# We use SILENCE_TIMEOUT_HOURS regardless of whether we create a silence for
# the initial maintenance or for a delayed worker pool maintenance, when we
# trigger on `UpgradeComplete` and `MachineConfigPoolUnpause`.
endsAt="$(date -u +'%Y-%m-%dT%H:%M:%S' --date "+${SILENCE_TIMEOUT_HOURS} hours")"

# Expire silence on Finish or UpgradeComplete events. Also use
# SILENCE_AFTER_FINISH_MINUTES when expiring silence before paused pools are
# updated.
if [ "${EVENT_name}" = "\"Finish\"" ] || [ "${EVENT_name}" = "\"UpgradeComplete\"" ]; then
  endsAt="$(date -u +'%Y-%m-%dT%H:%M:%S' --date "+${SILENCE_AFTER_FINISH_MINUTES} minutes")"
fi

while IFS= read -r silence; do
  cmsg=$(printf %s "${silence}" | jq -r '.comment')
  comment="Maintenance silence '${cmsg}' from '${job_name}'"

  body=$(printf %s "$silence" | \
    jq \
      --arg comment "${comment}" \
      --arg startsAt "${startsAt}" \
      --arg endsAt "${endsAt}" \
      --arg createdBy "Upgrade job '${job_name}'" \
      '.startsAt = $startsAt | .endsAt = $endsAt | .createdBy = $createdBy | .comment = $comment'
  )

  id=$(curl "${curl_opts[@]}" | jq --arg comment "${comment}" -r '.[] | select(.status.state == "active") | select(.comment == $comment) | .id' | head -n 1)
  if [ -n "${id}" ]; then
    echo "Updating silence with id '${id}' ..."
    body=$(printf %s "${body}" | jq --arg id "${id}" '.id = $id')
  else
    echo "Creating silence ..."
  fi

  curl "${curl_opts[@]}" -XPOST -d "${body}"
done <<<"$(printf %s "${SILENCES_JSON}" | jq -cr '.[]')"
