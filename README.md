# apigee-ledgerline

An Apigee X API proxy fronting **Ledgerline**, a live recurring-billing API (FastAPI). Built
hands-on to work through enterprise Apigee patterns end to end: a thin proxy over a real backend, a
shared-flow policy spine (security, error handling, logging), API products and quota, and APIOps
CI/CD.

The gateway owns the edge concerns — API-key verification, quota, CORS, RFC 9457 errors, structured
logging — so the backend stays thin.

## Structure

```
proxies/      API proxy bundles (ledgerline-v1)
sharedflows/  reusable policy flows (security, error handling, logging)
config/       per-environment config (target servers, products) — deployed, not baked into bundles
infra/        ephemeral ingress (Terraform) for testing an internal-only eval org
pipeline/     CI/CD: lint → build once → deploy
specs/        the Ledgerline OpenAPI contract the proxy is scaffolded from
```

## Environment

Apigee X evaluation org, **internal access only**, `europe-west9`. Nothing is exposed permanently;
external calls for testing go through an ephemeral load balancer (`infra/ephemeral-lb`) that is torn
down after use.
