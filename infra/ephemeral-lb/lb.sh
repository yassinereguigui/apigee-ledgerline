#!/usr/bin/env bash
# Ephemeral Apigee eval ingress: spin the LB up, get a public IP to curl, tear it down.
#
#   ./lb.sh up                 # create the LB, print the IP + a ready curl
#   ./lb.sh up --ttl 2h        # create it AND auto-destroy after 2h (background timer)
#   ./lb.sh down               # destroy everything
#   ./lb.sh ip                 # print the current IP + curl (if up)
#
# Requires: gcloud (authed), terraform, jq. Run from this directory.
set -euo pipefail
cd "$(dirname "$0")"

TOKEN() { gcloud auth print-access-token; }
API="https://apigee.googleapis.com/v1"

discover() {
  ORG="$(gcloud config get-value project 2>/dev/null)"
  [ -n "$ORG" ] || { echo "No gcloud project set. Run: gcloud config set project <ID>"; exit 1; }
  INSTANCE="$(curl -s -H "Authorization: Bearer $(TOKEN)" "$API/organizations/$ORG/instances" | jq -r '.instances[0].name')"
  DESC="$(curl -s -H "Authorization: Bearer $(TOKEN)" "$API/organizations/$ORG/instances/$INSTANCE")"
  SA="$(echo "$DESC" | jq -r '.serviceAttachment')"
  REGION="$(echo "$DESC" | jq -r '.location')"
  HOST="$(curl -s -H "Authorization: Bearer $(TOKEN)" "$API/organizations/$ORG/envgroups" | jq -r '.environmentGroups[0].hostnames[0]')"
  [ "$SA" != "null" ] && [ -n "$SA" ] || { echo "No service attachment on instance '$INSTANCE'. Is the eval instance fully provisioned?"; exit 1; }
  cat > eval.auto.tfvars <<EOF
project_id         = "$ORG"
region             = "$REGION"
service_attachment = "$SA"
envgroup_hostname  = "$HOST"
# network/subnetwork default to "default"; override here if your eval used a custom VPC.
EOF
  echo "Discovered: org=$ORG instance=$INSTANCE region=$REGION host=$HOST"
}

case "${1:-}" in
  up)
    discover
    terraform init -input=false >/dev/null
    terraform apply -auto-approve
    echo; echo "==> Try it (wait ~1-3 min for TLS to go live):"; terraform output -raw test_curl; echo
    if [ "${2:-}" = "--ttl" ] && [ -n "${3:-}" ]; then
      SECS="$(echo "$3" | sed 's/h/*3600/; s/m/*60/; s/s//' | bc)"
      echo "==> Auto-destroy scheduled in $3 (background). Log: teardown.log"
      nohup bash -c "sleep $SECS; cd '$PWD'; terraform destroy -auto-approve" >teardown.log 2>&1 &
      disown
    fi
    ;;
  down)
    terraform destroy -auto-approve
    ;;
  ip)
    terraform output -raw lb_ip; echo; terraform output -raw test_curl; echo
    ;;
  *)
    echo "usage: $0 {up [--ttl 2h] | down | ip}"; exit 1;;
esac
