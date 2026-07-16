terraform {
  required_version = ">= 1.6"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

provider "google" { project = var.project_id }

resource "google_service_account" "deployer" {
  account_id   = "apigee-ci-deployer"
  display_name = "Apigee CI deployer (Github Actions via WIF)"
}

resource "google_project_iam_member" "api_admin" {
  project = var.project_id
  role    = "roles/apigee.apiAdminV2"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_project_iam_member" "env_admin" {
  project = var.project_id
  role    = "roles/apigee.environmentAdmin"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-pool"
  display_name              = "Github Actions"
  description               = "Trust boundry for Github Actions OIDC identities"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-provider"
  display_name                       = "Github OIDC"
  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }
  attribute_condition = "attribute.repository == '${var.github_repo}'"
  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "wif" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}