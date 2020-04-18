output "docker-ms-app_external_ip" {
  value = google_compute_instance.docker-ms-app[*].network_interface[0].access_config[0].nat_ip
}
