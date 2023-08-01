# add the terraform provider for gcp
provider "google" {
    credentials = file(var.gcp_credentials_file)
    project = "gcp-terraform-393401"
    region = var.region

    alias = "tf-gcp"
}