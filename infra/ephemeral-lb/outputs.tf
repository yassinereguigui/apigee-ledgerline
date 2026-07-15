output "lb_ip" {
  value       = google_compute_global_address.ip.address
  description = "The public IP of the ephemeral load balancer."
}

output "test_curl" {
  # --resolve fakes DNS (no public record for the hostname); -k accepts the self-signed cert.
  value = "curl -k --resolve ${var.envgroup_hostname}:443:${google_compute_global_address.ip.address} https://${var.envgroup_hostname}/hello-world"
  description = "Ready-to-run command to hit your proxy from the internet."
}

output "note" {
  value = "TLS on the LB may take 1-3 min to go live after apply. If you get a handshake error, wait and retry."
}
