#!/bin/bash
set -euo pipefail

job_name="$JOB_metadata_name"

curl_opts=( "https://${ALERTMANAGER_HOST}.${ALERTMANAGER_NAMESPACE}.svc.cluster.local:9095/api/v2/silences" --cacert /etc/ssl/certs/serving-certs/service-ca.crt --header 'Content-Type: application/json' --header "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" --resolve "${ALERTMANAGER_HOST}.${ALERTMANAGER_NAMESPACE}.svc.cluster.local:9095:$(getent hosts "${ALERTMANAGER_OPERATED_SERVICE}.${ALERTMANAGER_NAMESPACE}.svc.cluster.local" | awk '{print $1}' | head -n 1)" --silent )

startsAt="$(date -u +'%Y-%m-%dT%H:%M:%S' --date '-5 minutes')"
endsAt="$(date -u +'%Y-%m-%dT%H:%M:%S' --date "+${SILENCE_TIMEOUT_HOURS} hours")"

if [ "${EVENT_name}" = "\"Finish\"" ]; then
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

  id=$(curl "${curl_opts[@]}" | jq -r ".[] | select(.status.state == \"active\") | select(.comment == \"${comment}\") | .id" | head -n 1)
  if [ -n "${id}" ]; then
    body=$(printf %s "${body}" | jq --arg id "${id}" '.id = $id')
  fi

  curl "${curl_opts[@]}" -XPOST -d "${body}"
done <<<"$(printf %s "${SILENCES_JSON}" | jq -cr '.[]')"
