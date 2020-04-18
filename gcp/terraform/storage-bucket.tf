terraform {
  required_version = "~>0.12.8"
}

provider "google" {
  version = "~> 2.15"
  project = var.project
  region  = var.region
}

module "storage-bucket" {
  source      = "SweetOps/storage-bucket/google"
  version     = "0.3.0"
  location    = var.region
  environment = "all"
  name        = var.name_bucket
}

output storage-bucket_url {
  value = module.storage-bucket.url
}
