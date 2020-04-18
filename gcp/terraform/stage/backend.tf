terraform {
  backend "gcs" {
    bucket = "all-storage-bucket-tf2"
    prefix = "terraform/st"
  }
}
