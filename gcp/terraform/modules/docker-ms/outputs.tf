output "docker-ms_external_ip" {
  value = google_compute_instance.docker-ms[*].network_interface[0].access_config[0].nat_ip
}
