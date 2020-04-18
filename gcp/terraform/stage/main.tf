terraform {
  # Версия terraform
  required_version = "~>0.12.24"
}

provider "google" {
  # Версия провайдера
  version = "~>2.15"
  project = var.project
  region  = var.region
}

module "docker-ms-app" {
  source           = "../modules/docker-ms-app"
  public_key_path  = var.public_key_path
  private_key_path = var.private_key_path
  zone             = var.zone
  region           = var.region
  app_disk_image   = var.app_disk_image
  label_env        = var.label_env
}

module "vpc" {
  source           = "../modules/vpc"
  source_ranges    = var.source_ranges
  public_key_path  = var.public_key_path
  private_key_path = var.private_key_path
}
