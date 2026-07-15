variable "project_id" {
  type        = string
  description = "GCP project = your Apigee eval org name."
}

variable "region" {
  type        = string
  description = "Region of the Apigee eval instance (same as the service attachment). e.g. europe-west1."
}

variable "service_attachment" {
  type        = string
  description = "The eval instance's PSC service attachment URI. Auto-filled by lb.sh (or: apigee API instances.get -> .serviceAttachment)."
}

variable "envgroup_hostname" {
  type        = string
  description = "The eval env-group hostname (e.g. PROJECT.apigee.net). Used for the cert CN and the curl Host."
}

variable "network" {
  type        = string
  default     = "default"
  description = "VPC that hosts the PSC NEG. The eval's authorized network (usually 'default')."
}

variable "subnetwork" {
  type        = string
  default     = "default"
  description = "Regional subnet in `network` (in `region`) for the PSC NEG. For the default VPC this is 'default'."
}
