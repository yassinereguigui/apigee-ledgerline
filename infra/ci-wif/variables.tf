variable "project_id" {
  type        = string
  description = "GCP project = the Apigee org that owns the deploy SA and WIF pool"
}

variable "github_repo" {
  type        = string
  description = "Github repo allowed to impersonate the deploy SA as 'owner/repo'. Pins WIF admission and the impersonation binding"
}