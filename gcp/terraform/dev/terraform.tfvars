project               = "immon4ik-infra"
public_key_path       = "~/otus/key/ssh/immon4ik-for-terraform.pub"
private_key_path      = "~/otus/key/ssh/immon4ik-for-terraform.pri"
disk_image            = "docker-ms-1587136740"
count_app             = "1"
health_check_port     = "8000"
hc_check_interval_sec = "1"
hc_timeout_sec        = "1"
label_env             = "dev"
