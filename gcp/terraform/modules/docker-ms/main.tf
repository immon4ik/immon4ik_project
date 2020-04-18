# Основное ресурса инстанса.
resource "google_compute_instance" "docker-ms" {
  count        = var.count_app
  name         = "${var.name_app}-${count.index}"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = var.tags
  boot_disk {
    initialize_params {
      image = var.app_disk_image
    }
  }

  # Метки
  labels = {
    ansible_group = var.label_ansible_group
    env           = var.label_env
  }

  # Параметры пользователя.
  metadata = {
    ssh-keys = "${var.user_name}:${file(var.public_key_path)}"
  }

  # Настройки сети.
  network_interface {
    network = var.network_name
    access_config {
      nat_ip = google_compute_address.app_ip.address
    }
  }

  # Параметры подключения провижионеров.
  connection {
    type        = var.connection_type
    host        = self.network_interface[0].access_config[0].nat_ip
    user        = var.user_name
    agent       = false
    private_key = file(var.private_key_path)
  }

  # Зависимости.
  # depends_on = [var.modules_depends_on]

  # Провижионеры.
  # provisioner "file" {
  #   source      = "${path.module}/files/set_env.sh"
  #   destination = "/tmp/set_env.sh"
  # }

  # provisioner "remote-exec" {
  #   inline = [
  #     "/bin/chmod +x /tmp/set_env.sh",
  #     "/tmp/set_env.sh ${var.database_url}",
  #   ]
  # }
}

# Основное ресурса брандмауэра.
# resource "google_compute_firewall" "firewall_puma" {
#   name    = var.fw_name
#   network = var.network_name
#   allow {
#     protocol = var.fw_allow_protocol
#     ports    = var.fw_allow_ports
#   }
#   source_ranges = var.fw_source_ranges
#   target_tags   = var.tags
# }

# Основное ресурса адреса хоста.
resource "google_compute_address" "app_ip" {
  name   = var.app_ip_name
  region = var.region
}
