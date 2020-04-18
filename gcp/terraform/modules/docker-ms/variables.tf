variable count_app {
  type    = string
  default = "1"
}

variable name_app {
  type    = string
  default = "docker-ms"
}

variable machine_type {
  type    = string
  default = "g1-small"
}

variable zone {
  type    = string
  default = "europe-west1-b"
}

variable region {
  type    = string
  default = "europe-west-1"
}

variable tags {
  type    = list(string)
  default = ["docker-ms", "http-server"]
}

variable app_disk_image {
  default = "docker-ms-1587136740"
}

variable label_ansible_group {
  type    = string
  default = "docker-ms"
}

variable label_env {
  type        = string
  description = "dev, stage, prod and etc."
  default     = "dev"
}

variable network_name {
  type    = string
  default = "default"
}

variable user_name {
  type    = string
  default = "immon4ik"
}

variable public_key_path {
  type    = string
  default = ""
}

variable private_key_path {
  type    = string
  default = ""
}

variable connection_type {
  type    = string
  default = "ssh"
}

variable app_ip_name {
  type    = string
  default = "docker-ms-ip"
}

variable fw_name {
  type    = string
  default = "allow-project-default"
}

variable fw_allow_protocol {
  type    = string
  default = "tcp"
}

variable fw_allow_ports {
  type    = list(string)
  default = ["8000"]
}

variable fw_source_ranges {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable modules_depends_on {
  type    = any
  default = null
}
