# Основное ресурса брандмауэра.
resource "google_compute_firewall" "firewall_ssh" {
  name        = var.name_fw
  description = "Allow SSH from anywhere"
  network     = var.network_name
  priority    = 65534
  allow {
    protocol = var.fw_allow_protocol
    ports    = var.fw_allow_ports
  }
  source_ranges = var.source_ranges
  depends_on    = [var.modules_depends_on]
}

# Основное ресурса метаданных.
resource "google_compute_project_metadata_item" "custom-metadata-ssh" {
  key   = var.meta_key
  value = "${var.user_name}:${chomp(file(var.public_key_path))}"
}
