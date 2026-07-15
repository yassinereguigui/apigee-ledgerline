# Ephemeral external ingress for an Apigee eval instance.
# Creates ONLY the northbound LB pieces (PSC NEG -> Apigee service attachment) so you can
# curl your proxy from the internet, then `destroy` them when done. Nothing here touches the
# Apigee org/instance itself. The only hourly cost is the forwarding rule (~$0.025/hr) + IP.
#
# Works on an existing eval instance (no re-provisioning): northbound PSC is supported on any
# instance, and the service attachment is auto-created with the instance. See ../02 §4.1.

terraform {
  required_version = ">= 1.6"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
    tls    = { source = "hashicorp/tls",    version = "~> 4.0" }
  }
}

provider "google" { project = var.project_id }

# 1) Reserved global external IP (the address you'll curl).
resource "google_compute_global_address" "ip" {
  name = "apigee-eval-lb-ip"
}

# 2) Self-signed cert for the env-group hostname — test only; you'll curl with -k.
#    (A Google-managed cert needs a real domain + DNS + ~15-60 min; too slow for spin-up/tear-down.)
resource "tls_private_key" "k" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
resource "tls_self_signed_cert" "c" {
  private_key_pem       = tls_private_key.k.private_key_pem
  validity_period_hours = 48
  early_renewal_hours   = 3
  allowed_uses          = ["digital_signature", "key_encipherment", "server_auth"]
  dns_names             = [var.envgroup_hostname]
  subject { common_name = var.envgroup_hostname }
}
resource "google_compute_ssl_certificate" "cert" {
  name        = "apigee-eval-lb-cert"
  private_key = tls_private_key.k.private_key_pem
  certificate = tls_self_signed_cert.c.cert_pem
}

# 3) PSC NEG pointing at the Apigee instance's service attachment (no MIG, no VMs).
resource "google_compute_region_network_endpoint_group" "psc_neg" {
  name                  = "apigee-eval-psc-neg"
  region                = var.region
  network               = var.network
  subnetwork            = var.subnetwork
  network_endpoint_type = "PRIVATE_SERVICE_CONNECT"
  psc_target_service    = var.service_attachment
  lifecycle { create_before_destroy = true }
}

# 4) Global external backend service -> the PSC NEG (HTTPS to Apigee; no health check for PSC NEGs).
resource "google_compute_backend_service" "bs" {
  name                  = "apigee-eval-bs"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_name             = "https"
  backend { group = google_compute_region_network_endpoint_group.psc_neg.id }
}

# 5) URL map -> target HTTPS proxy -> global forwarding rule on :443.
resource "google_compute_url_map" "um" {
  name            = "apigee-eval-um"
  default_service = google_compute_backend_service.bs.id
}
resource "google_compute_target_https_proxy" "proxy" {
  name             = "apigee-eval-proxy"
  url_map          = google_compute_url_map.um.id
  ssl_certificates = [google_compute_ssl_certificate.cert.id]
}
resource "google_compute_global_forwarding_rule" "fr" {
  name                  = "apigee-eval-fr"
  target                = google_compute_target_https_proxy.proxy.id
  ip_address            = google_compute_global_address.ip.id
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}
