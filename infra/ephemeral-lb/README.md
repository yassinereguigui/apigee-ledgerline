# Ephemeral LB for an Apigee eval instance

Spin up internet access to your eval proxy **only while you're testing**, then tear it down —
so you pay cents (hourly), not the ~$20–25/mo the wizard quotes for a 24×7 load balancer.

## Why this works
The Apigee eval org is free; the **external load balancer is a separate, billable GCP resource**
(`../02 §4.1`). But it's billed **hourly** (forwarding rule ≈ $0.025/hr + a small IP charge), and
**northbound PSC works on any existing eval instance** — so you can attach an LB and remove it on
demand without re-provisioning Apigee. Run it 1h/day for a month ≈ **~$0.75**, not $25.

This creates only the LB pieces (static IP → HTTPS proxy → URL map → backend service → **PSC NEG →
your instance's service attachment**). Nothing touches the Apigee org/instance. See `main.tf`.

## Use it
```bash
gcloud config set project <YOUR_EVAL_PROJECT>   # = your eval org
chmod +x lb.sh

./lb.sh up               # discovers your instance's service attachment, builds the LB, prints a curl
./lb.sh up --ttl 2h      # same, but auto-destroys after 2h (background timer)
./lb.sh ip               # reprint IP + curl
./lb.sh down             # tear it all down
```
`up` auto-fills `eval.auto.tfvars` (project, region, service attachment, env-group hostname) by
querying the Apigee API — no manual copying. Then curl the printed command:
```bash
curl -k --resolve PROJECT.apigee.net:443:<LB_IP> https://PROJECT.apigee.net/hello-world
# -> Hello, Guest!    (wait 1-3 min after apply for the LB's TLS to go live)
```
`-k` accepts the self-signed test cert; `--resolve` fakes DNS (no public record needed).

Prereqs: `gcloud` (authenticated), `terraform`, `jq`. Default VPC assumed — if your eval used a
custom network, set `network`/`subnetwork` in `eval.auto.tfvars`.

## The backend to call
Point your proxy's target at a public mock and the proxy→backend hop needs **no LB** (it's egress):
`https://mocktarget.apigee.net` (returns `Hello, Guest!`) or `https://httpbin.org/get`. See
`../proxy-sample/apiproxy/targets/default.xml`.

## Auto-teardown: three options, honest trade-offs
1. **`--ttl` background timer (built in).** Simplest. Caveat: it's a local `sleep` — if your
   machine sleeps/reboots, the auto-destroy won't fire. Fine for a working session.
2. **Just run `./lb.sh down`** when you finish. Most reliable if you remember.
3. **Cloud-side self-destruct (robust, survives your laptop).** Schedule a delete in GCP:
   ```bash
   # delete just the hourly-billed forwarding rule after 2h, from the cloud
   gcloud scheduler jobs create http kill-apigee-lb \
     --schedule="$(date -u -v+2H +'%M %H %d %m *')" \
     --uri="https://compute.googleapis.com/compute/v1/projects/$(gcloud config get-value project)/global/forwardingRules/apigee-eval-fr" \
     --http-method=DELETE --oauth-service-account-email=<SA> --location=<REGION>
   ```
   (Then `./lb.sh down` later to clean up the rest.) Heavier to set up; use if you're forgetful.

## Safety net (do this once): a budget alert
Don't rely on a timer alone — set a cheap tripwire so a forgotten LB can never surprise you:
```bash
gcloud billing budgets create --billing-account=<BILLING_ACCT> \
  --display-name="apigee-eval-guard" --budget-amount=5USD \
  --threshold-rule=percent=0.5 --threshold-rule=percent=1.0
```
A forgotten LB is ~$0.60/day, so a $5 budget alerts you long before it matters.

## Cleanup checklist
- `./lb.sh down` (removes IP, cert, NEG, backend, URL map, proxy, forwarding rule)
- Confirm nothing lingers: `gcloud compute forwarding-rules list && gcloud compute addresses list`
- The eval org keeps running (free) — only the LB is gone.
