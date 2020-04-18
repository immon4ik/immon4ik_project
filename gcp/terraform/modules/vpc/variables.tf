variable name_fw {
  default = "custom-allow-ssh"
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

variable fw_allow_protocol {
  type    = string
  default = "tcp"
}

variable fw_allow_ports {
  type    = list(string)
  default = ["22"]
}

variable source_ranges {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

variable modules_depends_on {
  type    = any
  default = null
}

variable meta_key {
  type    = string
  default = "ssh-keys"
}
