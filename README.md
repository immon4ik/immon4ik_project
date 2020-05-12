# Карта выполнения проекта.

- [Карта выполнения проекта.](#карта-выполнения-проекта)
  - [immon4ik_project](#immon4ik_project)
  - [15.04.2020. Создание образов контейнеров, сценария запуска приложения от otus. Проверка работы приложения.](#15042020-создание-образов-контейнеров-сценария-запуска-приложения-от-otus-проверка-работы-приложения)
    - [Поймал проблемы с выполнением sh скриптов в ENTRYPOINT \["docker-entrypoint.sh"\]](#поймал-проблемы-с-выполнением-sh-скриптов-в-entrypoint-docker-entrypointsh)
  - [16.04.2020. Написание сценариев подключения к gcp. Упаковка образа и сборка _управляющего хоста_ с установленным docker, docker-compose, docker-machine на базе imubuntu-1604-lts. Применение packer, ansible и terraform.](#16042020-написание-сценариев-подключения-к-gcp-упаковка-образа-и-сборка-_управляющего-хоста_-с-установленным-docker-docker-compose-docker-machine-на-базе-imubuntu-1604-lts-применение-packer-ansible-и-terraform)
    - [Работы ведутся в инраструктурном проекте gcp - immon4ik-infra.](#работы-ведутся-в-инраструктурном-проекте-gcp---immon4ik-infra)
    - [Работаем с хостом сборки myhost.](#работаем-с-хостом-сборки-myhost)
  - [17.04.2020. Доработка плейбука ansible для установки docker, docker-compose, docker-machine.](#17042020-доработка-плейбука-ansible-для-установки-docker-docker-compose-docker-machine)
  - [18.04.2020. В первой части реализации проекта, я создал сценарий деплоя приложения от otus, используя docker-compose. Используем его в другом модуле для terraform: docker-ms-app в контуре stage.](#18042020-в-первой-части-реализации-проекта-я-создал-сценарий-деплоя-приложения-от-otus-используя-docker-compose-используем-его-в-другом-модуле-для-terraform-docker-ms-app-в-контуре-stage)
    - [Работаем с _управляющим хостом_ docker-ms.](#работаем-с-_управляющим-хостом_-docker-ms)

------------------

## immon4ik_project

------------------

## __Основной задачей проекта является закрепить практику по курсу.__

------------------

### 15.04.2020.

#### Создание образов контейнеров, сценария запуска приложения от otus. Проверка работы приложения.

<details>
  <summary>15.04.2020. Работа с приложением проекта.</summary>

- Поднятие хоста с помощью docker-machine для тестирования работ приложения от otus.

```bash
export GOOGLE_PROJECT=my_project
docker-machine create --driver google \
 --google-machine-image "ubuntu-os-cloud/global/images/ubuntu-1604-xenial-v20200407" \
 --google-disk-size "50" --google-disk-type "pd-standard" \
 --google-machine-type "n1-standard-1" --google-zone europe-west1-b docker-project

```

- Для проверки работы добавляем правило firewall созданному хосту docker-project.

```bash
gcloud compute firewall-rules create docker-machine-allow-http \
  --allow tcp:80 \
  --target-tags=docker-machine \
  --description="Allow http connections" \
  --direction=INGRESS

gcloud compute firewall-rules create docker-machine-allow-https \
  --allow tcp:443 \
  --target-tags=docker-machine \
  --description="Allow https connections" \
  --direction=INGRESS

gcloud compute firewall-rules create rabbitmq \
  --allow tcp:8081 \
  --target-tags=docker-machine \
  --description="Allow RabbitMQ Mgmt connections" \
  --direction=INGRESS

gcloud compute firewall-rules create project-ui \
  --allow tcp:8000 \
  --target-tags=docker-machine \
  --description="Allow Project UI connections" \
  --direction=INGRESS

```

- Переходим к работе с docker-project.

```bash
eval $(docker-macine env docker-project)

```

- Создадим две сети docker.

```bash
docker network create back_net --subnet=10.0.2.0/24
docker network create front_net --subnet=10.0.1.0/24

```

- Запустим котейнер mongodb в подсети back_net.

```bash
docker run -d --network=back_net --name mongo_db \
 --network-alias=crawler_db mongo:latest

```

- Подключем mongodb к сети front_net.

```bash
docker network connect --alias ui_db front_net mongo_db

```

- Запустим контейнер rabbitmq в подсети back_net.

```bash
# Проброшен порт в консоль управления.
docker run -d --network=back_net -p 8081:15672 --hostname my_rabbit_mq --name rabbit_mq \
 --network-alias=crawler_mq --network-alias=ui_mq rabbitmq:3-management

# Без консоли управления.
docker run -d --network=back_net --hostname my_rabbit_mq --name rabbit_mq \
 --network-alias=crawler_mq --network-alias=ui_mq rabbitmq:3.8.3-alpine

```

- Входим в dockerhub для билда в него образов.

```bash
docker login -u mylogin -p mypass
```

- Пробуем собрать образ для project-crawler.
src/project-crawler/Dockerfile:

```dockerfile
FROM python:3.6.0-alpine

WORKDIR /app
COPY . /app

RUN apk --no-cache --update add build-base=0.4-r1 \
    && pip install -r /app/requirements.txt \
    && apk del build-base

ENV MONGO crawler_db
ENV MONGO_PORT 27017
ENV RMQ_HOST crawler_mq
ENV RMQ_QUEUE project
ENV RMQ_USERNAME guest
ENV RMQ_PASSWORD guest
ENV CHECK_INTERVAL 60
ENV EXCLUDE_URLS .*github.com

RUN chmod +x docker-entrypoint.sh
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
RUN ln -s usr/local/bin/docker-entrypoint.sh /

ENTRYPOINT ["docker-entrypoint.sh"]
# ENTRYPOINT sleep 10 && python3 -u crawler/crawler.py https://vitkhab.github.io/search_engine_test_site/

```

- Пишем docker-entrypoint.sh для контейнера crawler.

```bash
#!/bin/sh
set -e

sleep 5
cd crawler && python3 -u crawler.py https://vitkhab.github.io/search_engine_test_site/

```

- Билдим образ crawler в свой docker hub.

```bash
docker build -t immon/project-crawler:1.0 ./project-crawler

```

- Запустим контейнер с crawler в сети back_net.

```bash
docker run -d --network=back_net --name crawler --restart always \
 --network-alias=crawler immon/project-crawler:1.0

```

- Пишем Dockerfile билда образ для контейнера ui.
src/project-ui/Dockerfile:

```dockerfile
FROM python:3.8.2-alpine

WORKDIR /app
COPY . /app

RUN apk --no-cache --update add build-base=0.5-r1 \
    && pip install -r /app/requirements.txt \
    && apk del build-base

ENV MONGO ui_db
ENV MONGO_PORT 27017
ENV FLASK_APP ui.py

RUN chmod +x docker-entrypoint.sh
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
RUN ln -s usr/local/bin/docker-entrypoint.sh /

ENTRYPOINT ["docker-entrypoint.sh"]
# ENTRYPOINT cd ui && gunicorn ui:app -b 0.0.0.0

```

- Пишем docker-entrypoint.sh для контейнера ui.

```bash
#!/bin/sh
set -e

cd ui && gunicorn ui:app -b 0.0.0.0

```

- Билдим образ project-ui в свой docker hub.

```bash
docker build -t immon/project-ui:1.0 ./project-ui

```

- Запустим контейнер с crawler в сети front_net.

```bash
docker run -d --network=front_net -p 8000:8000 --name ui --restart always \
 --network-alias=ui immon/project-ui:1.0

```

- Пишем параметризированый yml для запуска приложения при помощи docker-compose:
/src/docker-compose.yml

```yml
version: '3.7'
services:
  mongo_db:
    image: ${MONGO_DB_IMAGE}
    volumes:
      - ${MONGO_DB_VOL_NAME}:${MONGO_DB_VOL_DEST}
    networks:
        back_net:
            aliases:
                - ${MONGO_DB_BACK_NET_ALIAS}
        front_net:
            aliases:
                - ${MONGO_DB_FRONT_NET_ALIAS}
  rabbit_mq:
    depends_on:
      - mongo_db
    image: ${RABBIT_MQ_IMAGE}
    volumes:
      - ${RABBIT_MQ_VOL_HOME_NAME}:${RABBIT_MQ_VOL_HOME_DEST}
      - ${RABBIT_MQ_VOL_CONFIG_NAME}:${RABBIT_MQ_VOL_CONFIG_DEST}
    networks:
      back_net:
        aliases:
          - ${RABBIT_MQ_BACK_NET_ALIAS}
  crawler:
    build: ${CRAWLER_BUILD_PATH}
    depends_on:
      - rabbit_mq
    image: ${DOCKER_HUB_USERNAME}/${CRAWLER_IMAGE}:${CRAWLER_IMAGE_VERSION}
    volumes:
      - ${CRAWLER_VOL_NAME}:${CRAWLER_VOL_DEST}
    networks:
      - ${NETWORK_BACK_NET}
  ui:
    build: ${UI_BUILD_PATH}
    depends_on:
      - crawler
    image: ${DOCKER_HUB_USERNAME}/${UI_IMAGE}:${UI_IMAGE_VERSION}
    volumes:
      - ${UI_VOL_NAME}:${UI_VOL_DEST}
    ports:
      - ${UI_PORT}:${UI_PORT}/tcp
    networks:
      - ${NETWORK_FRONT_NET}

volumes:
  db_crawler:
  mq_rabbit_home:
  mq_rabbit_config:
  bot_crawler:
  app_ui:

networks:
  back_net:
    driver: ${NETWORK_BACK_NET_DRIVER}
    ipam:
      driver: default
      config:
        - subnet: ${NETWORK_BACK_NET_SUBNET}
  front_net:
    driver: ${NETWORK_FRONT_NET_DRIVER}
    ipam:
      driver: default
      config:
        - subnet: ${NETWORK_FRONT_NET_SUBNET}

```

- Переменные вынесены в отдельный файл .env, gпример файла, переопределяющего инструкции docker-compose.yml - docker-compose.override.yml.example.
/src/.env

```env
# Общие переменные среды всего проекта.
COMPOSE_PROJECT_NAME=immon4ik_project
DOCKER_HUB_USERNAME=immon
NETWORK_BACK_NET=back_net
NETWORK_FRONT_NET=front_net
NETWORK_BACK_NET_DRIVER=bridge
NETWORK_FRONT_NET_DRIVER=bridge
NETWORK_BACK_NET_SUBNET=10.0.5.0/24
NETWORK_FRONT_NET_SUBNET=10.0.4.0/24

# Переменные среды окружения mongo_db.
MONGO_DB_IMAGE=mongo:latest
MONGO_DB_VOL_NAME=db_crawler
MONGO_DB_VOL_DEST=/data/db
MONGO_DB_BACK_NET_ALIAS=crawler_db
MONGO_DB_FRONT_NET_ALIAS=ui_db

# Переменные среды окружения rabbit_mq.
RABBIT_MQ_IMAGE=rabbitmq:3.8.3-alpine
RABBIT_MQ_VOL_HOME_NAME=mq_rabbit_home
RABBIT_MQ_VOL_HOME_DEST=/var/lib
RABBIT_MQ_VOL_CONFIG_NAME=mq_rabbit_config
RABBIT_MQ_VOL_CONFIG_DEST=/etc/rabbitmq
RABBIT_MQ_BACK_NET_ALIAS=crawler_mq

# Переменные среды окружения crawler.
CRAWLER_BUILD_PATH=./project-crawler
CRAWLER_IMAGE=project-crawler
CRAWLER_IMAGE_VERSION=1.1
CRAWLER_VOL_NAME=bot_crawler
CRAWLER_VOL_DEST=/app

# Переменные среды окружения ui.
UI_BUILD_PATH=./project-ui
UI_IMAGE=project-ui
UI_IMAGE_VERSION=1.1
UI_VOL_NAME=app_ui
UI_VOL_DEST=/app
UI_PORT=8000

```

- Запускаем поднятие приложения, проверку списка контейнеров и их лог с промощью docker-compose:

```bash
dockr-compose up -d
dockr-compose ps -a
dockr-compose logs mongo_db rabbit_mq crawler ui

```

[Карта выполнения проекта](#карта-выполнения-проекта)

</details>

#### Поймал проблемы с выполнением sh скриптов в ENTRYPOINT ["docker-entrypoint.sh"]

<details>
  <summary>15.04.2020. Ошибка ENTRYPOINT.</summary>

Ошибка - “exec: “docker-entrypoint.sh”: stat docker-entrypoint.sh: no such file or directory”. На windows хостах их следует создавать с параметром "select end of line sequence" равным LF или в nix системе - <https://stackoverflow.com/questions/55786898/standard-init-linux-go190-exec-user-process-caused-exec-format-error-when-ru>

[Карта выполнения проекта](#карта-выполнения-проекта)

</details>

------------------

### 16.04.2020.

#### Написание сценариев подключения к gcp. Упаковка образа и сборка _управляющего хоста_ с установленным docker, docker-compose, docker-machine на базе imubuntu-1604-lts. Применение packer, ansible и terraform.

<details>
  <summary>16.04.2020. Разработка кода для инфраструктуры проекта.</summary>

- Для выполнения проекта используется windows хост:

```powershell
Get-ComputerInfo
WindowsBuildLabEx                                       : 14393.3595.amd64fre.rs1_release_inmarket.200312-1730
WindowsCurrentVersion                                   : 6.3
WindowsEditionId                                        : ServerStandard
WindowsInstallationType                                 : Server
[...]
$PSVersionTable.PSVersion
Major  Minor  Build  Revision
-----  -----  -----  --------
5      1      14393  3471

```

- На хост предварительно установлены: 1. VSC - <https://code.visualstudio.com/download>; 2. Python27 - <https://www.python.org/downloads/windows/>; 3. Cloud SDK - <https://cloud.google.com/sdk/docs/>; 4. Ruby - <https://rubyinstaller.org/downloads/>; 5. OpenSSH - <https://github.com/PowerShell/Win32-OpenSSH>

- Установлены дополнения для vsc, сгенерированы и добавлены ssh ключи. Выполнена регистрация и инициализация в gcp - <https://cloud.google.com/?hl=RU>, создан проект в gcp для управляющего хоста на базе imubuntu-1604-lts - immon4ik-infra, создан сервисный аккаунт, скачан json-ключ. Полезный пул комманд:

```powershell
gcloud init
gcloud auth login
gcloud auth list
gcloud projects create PROJECT_ID
gcloud auth application-default login
gcloud iam service-accounts create [SA-NAME] `
    --description "[SA-DESCRIPTION]" `
    --display-name "[SA-DISPLAY-NAME]"

```

[Карта выполнения проекта](#карта-выполнения-проекта)

</details>

#### Работы ведутся в инраструктурном проекте gcp - immon4ik-infra.

<details>
  <summary>16.04.2020. immon4ik-infra.</summary>

- Создадим сборочный хост в gcp т.к. для корректной работы связки packer, ansible, terraform предпочтительней использовать *nix систему(_подсистема WSL в процессе тестирования_):

```powershell
gcloud compute instances create myhost `
 --boot-disk-size=10GB `
 --image-family ubuntu-1604-lts `
 --image-project=ubuntu-os-cloud `
 --machine-type=g1-small `
 --tags ih1 `
 --restart-on-failure `
 --metadata-from-file startup-script=gcp/scripts/install.sh
[...]
c
```

- Создаем загрузочный скрипт - <https://cloud.google.com/compute/docs/startupscript#gcloud_2> - gcp/scripts/install.sh:

```bash
#!/bin/bash

# Обновляем и устанавливаем софт.
sudo apt --assume-yes update
sudo apt --assume-yes upgrade
sudo apt --assume-yes install ruby-full ruby-bundler build-essential wget git python-apt python-pip unzip

# Обновляем pip.
sudo pip install --upgrade pip

# Ставим ansible.
sudo apt --assume-yes install ansible

# Переменные среды окружения с актуальными версиями terraform и packer.
export VER_TERRAFORM="0.12.24"
export VER_PACKER="1.5.5"

# Качаем terraform и packer.
sudo wget https://releases.hashicorp.com/terraform/${VER_TERRAFORM}/terraform_${VER_TERRAFORM}_linux_amd64.zip
sudo wget https://releases.hashicorp.com/packer/${VER_PACKER}/packer_${VER_PACKER}_linux_amd64.zip

# Распаковываем terraform и packer.
sudo unzip terraform_${VER_TERRAFORM}_linux_amd64.zip
sudo unzip packer_${VER_PACKER}_linux_amd64.zip

# Ставим terraform и packer.
sudo mv terraform /usr/local/bin/
sudo mv packer /usr/local/bin/

# Линкуем terraform и packer.
sudo -H -u immon4ik bash -c 'which terraform'
sudo -H -u immon4ik bash -c 'which packer'
sudo -H -u immon4ik bash -c 'which ansible'
sudo -H -u immon4ik bash -c 'which pip'

# Проверка версии софта.
git --version
terraform -v
packer -v
ansible --version

```

- Команды для проверки и возможного дебага:

```powershell
ssh immon4ik@ip_myhost
cat /var/log/syslog
sudo google_metadata_script_runner --script-type startup --debug

gcloud compute instances add-metadata myhost `
 --metadata-from-file startup-script=gcp/scripts/install.sh

```

[Карта выполнения проекта](#карта-выполнения-проекта)

</details>

#### Работаем с хостом сборки myhost.

<details>
  <summary>16.04.2020. myhost.</summary>

- Выполнена инициализация и вход в gcp. Для синхронизации файлов на хосте сборки и windows хоста настроен плагин для vsc - SFTP - <https://github.com/liximomo/vscode-sftp.git>:  
./vscode/sftp.json  

```json
{
  "name": "myhost",
  "host": "ip_myhost",
  "protocol": "sftp",
  "port": 22,
  "username": "immon4ik",
  "privateKeyPath": "path/my_ssh",
  "remotePath": "path/my_project_folder",
  "downloadOnOpen": true,
  "uploadOnSave": true,
  "watcher": {
    "files": "**/*",
    "autoUpload": true,
    "autoDelete": true
    },
  "ignore": [".vscode", ".git", ".DS_Store"]
}

```

- Пишем шаблон для packer, плейбук для ansible:
/gcp/packer/docker-ms.json

```json
{
    "variables": {
        "project_id": null,
        "source_image_family": null,
        "machine_type": "g1-small",
        "image_description": "img for docker-ms",
        "disk_size": "10",
        "network": "default",
        "tags": "docker-ms"
    },
    "builders": [
        {
            "type": "googlecompute",
            "project_id": "{{ user `project_id` }}",
            "image_name": "docker-ms-{{timestamp}}",
            "image_family": "docker-ms-base",
            "source_image_family": "{{ user `source_image_family` }}",
            "zone": "europe-west1-b",
            "ssh_username": "immon4ik",
            "machine_type": "{{ user `machine_type` }}",
            "image_description": "{{ user `image_description` }}",
            "disk_size": "{{ user `disk_size` }}",
            "network": "{{ user `network` }}",
            "tags": "{{ user `tags` }}"
        }
    ],
    "provisioners": [
        {
            "type": "ansible",
            "playbook_file": "ansible/playbooks/packer_docker_ms.yml"
        }
    ]
}

```

[Карта выполнения проекта](#карта-выполнения-проекта)

</details>

------------------

### 17.04.2020.

#### Доработка плейбука ansible для установки docker, docker-compose, docker-machine.

<details>
  <summary>17.04.2020. Доработка кода инфраструктуры проекта.</summary>

- Пишем\дорабатываем плейбук ansible для установки docker, docker-compose, docker-machine:
/gcp/ansible/playbooks/packer_docker_ms.yml

```yml
- hosts: all
  become: yes
  gather_facts: false
  tasks:
  - name: Install docker packages
    remote_user: immon4ik
    apt:
      name: "{{ item }}"
      state: present
      update_cache: yes
    with_items:
      - apt-transport-https
      - ca-certificates
      - curl
      - software-properties-common
    tags:
      - docker-ms
  - name: Add Docker s official GPG key
    remote_user: immon4ik
    apt_key:
      url: https://download.docker.com/linux/ubuntu/gpg
      state: present
    tags:
      - docker-ms
  - name: Verify that we have the key with the fingerprint
    remote_user: immon4ik
    apt_key:
      id: 0EBFCD88
      state: present
    tags:
      - docker-ms
  - name: Set up the stable repository
    remote_user: immon4ik
    apt_repository:
      repo: deb [arch=amd64] https://download.docker.com/linux/ubuntu xenial stable
      state: present
      update_cache: yes
    tags:
      - docker-ms
  - name: Update apt packages
    remote_user: immon4ik
    apt:
      update_cache: yes
    tags:
      - docker-ms
  - name: Install docker
    remote_user: immon4ik
    apt:
      name: docker-ce
      state: present
      update_cache: yes
    tags:
      - docker-ms
  - name: Add remote "immon4ik" user to "docker" group
    remote_user: immon4ik
    user:
      name: "immon4ik"
      group: "docker"
      append: yes
    tags:
      - docker-ms
  - name: Install docker-compose
    remote_user: immon4ik
    get_url:
      url : https://github.com/docker/compose/releases/download/1.25.5/docker-compose-Linux-x86_64
      dest: /usr/local/bin/docker-compose
      group: docker
      mode: 'u+x,g+x,o+x'
    tags:
      - docker-ms
  - name: Install docker-machine
    remote_user: immon4ik
    get_url:
      url : https://github.com/docker/machine/releases/download/v0.16.2/docker-machine-Linux-x86_64
      dest: /usr/local/bin/docker-machine
      group: docker
      mode: 'u+x,g+x,o+x'
    tags:
      - docker-ms

```

- Запускаем проверку и создание образа:

```bash
cd gcp
packer validate -var-file=packer/variables.json packer/docker-ms.json
packer build -var-file=packer/variables.json packer/docker-ms.json
[...]
cat /packer/images_version.txt
17.04.2020
----------
ubuntu-1604-lts, docker, docker-compose, docker-machine:
v.1.1 - docker-ms-1587128793
v.1.1 - docker-ms-1587131816
v.1.3 - docker-ms-1587132771
v.1.4 - docker-ms-1587133818
v.1.5 - docker-ms-1587136740

```

- Пишем параметризированную инструкцию по поднятию _управляющего хоста_ используя terraform в виде модуля:  
/gcp/terraform/modules/docker-ms/main.tf

```t
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

```

- Параметризируем переменные модуля docker-ms:  
/gcp/terraform/modules/docker-ms/variables.tf

```t
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

```

- Добавляем вывод внешнего адреса поднятого _управляющего хоста_:
/gcp/terraform/modules/docker-ms/outputs.tf

```t
output "docker-ms_external_ip" {
  value = google_compute_instance.docker-ms[*].network_interface[0].access_config[0].nat_ip
}

```

- Напишем сценарий для поднятия _управляющего хоста_ в рамках контура dev:
/gcp/terraform/dev/main.tf

```t
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

module "docker-ms" {
  source           = "../modules/docker-ms"
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

```

- Параметризируем переменные контура dev:
/gcp/terraform/dev/variables.tf

```t
variable project {
  description = "Project ID"
}
variable region {
  description = "Region"
  default     = "europe-west1"
}

variable zone {
  description = "Zone"
  default     = "europe-west1-b"
}

variable public_key_path {
  description = "Path to the public key used for ssh access"
}

variable private_key_path {
  description = "Path to the private key used for ssh access"
}
variable disk_image {
  description = "Disk image"
}

variable count_app {
  default = "1"
}

variable name_app {
  default = "docker-ms"
}

variable health_check_port {
  description = "Port for healthcheck backend service."
}

variable instance_group_name_port {
  default = "http"
}

variable instance_group_port {
  default = "8000"
}

variable forwarding_rule_port_range {
  default = "80"
}

variable hc_check_interval_sec {
  default = "1"
}

variable hc_timeout_sec {
  default = "1"
}

variable app_disk_image {
  description = "Disk image for docker-ms"
  default     = "docker-ms-1587136740"
}

variable label_env {
  type        = string
  description = "dev, stage, prod and etc."
  default     = "dev"
}

variable source_ranges {
  description = "Allowed IP addresses"
  default     = ["0.0.0.0/0"]
}

```

- Изменяем значения переменных для контура dev:
/gcp/terraform/dev/terraform.tfvats

```t
project               = "immon4ik-infra"
public_key_path       = "~/otus/key/ssh/immon4ik.pub"
private_key_path      = "~/otus/key/ssh/immon4ik.pri"
disk_image            = "docker-ms-1587136740"
count_app             = "1"
health_check_port     = "8000"
hc_check_interval_sec = "1"
hc_timeout_sec        = "1"
label_env             = "dev"

```

- Переходим в папку контура dev. Форматируем синтаксис terraform. Инициализируем модули, проверяем возможность создания и собираем _управляющий хост_:

```bash
cd dev
terraform init
terraform fmt
terraform plan
terraform apply --auto-approve

```

- Полезные команды:

```bash
terraform import module.vpc.google_compute_firewall.firewall_ssh default-allow-ssh

```

- Входим на созданный хост. Проверяем работоспособность docker, docker-compose и docker-machine. __Данный хост в дальнейшем планируется использовать, как _управляющий хост_, для реализации управления жизнью приложения при помощи Gitlab CI.__

[Карта выполнения проекта](#карта-выполнения-проекта)

</details>

------------------

### 18.04.2020.

#### В первой части реализации проекта, я создал сценарий деплоя приложения от otus, используя docker-compose. Используем его в другом модуле для terraform: docker-ms-app в контуре stage.

<details>
  <summary>18.04.2020. Реализация приложения в gcp используя инструменты iac</summary>

- Пишем параметризированную инструкцию по поднятию _управляющего хоста_ используя terraform в виде модуля:  
/gcp/terraform/modules/docker-ms-app/main.tf

```t
# Основное ресурса инстанса.
resource "google_compute_instance" "docker-ms-app" {
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
      nat_ip = google_compute_address.docker-ms-app-app_ip.address
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
  provisioner "file" {
    source      = "${path.module}/files/"
    destination = "/tmp"
  }

  provisioner "remote-exec" {
    inline = [
      "/bin/chmod +x /tmp/deploy.sh",
      "/tmp/deploy.sh",
    ]
  }
}

# Основное ресурса брандмауэра.
resource "google_compute_firewall" "firewall_otus_app" {
  name    = var.fw_name
  network = var.network_name
  allow {
    protocol = var.fw_allow_protocol
    ports    = var.fw_allow_ports
  }
  source_ranges = var.fw_source_ranges
  target_tags   = var.tags
}

# Основное ресурса адреса хоста.
resource "google_compute_address" "docker-ms-app-app_ip" {
  name   = var.app_ip_name
  region = var.region
}

```

- Параметризируем переменные модуля docker-ms-app:  
/gcp/terraform/modules/docker-ms-app/variables.tf

```t
variable count_app {
  type    = string
  default = "1"
}

variable name_app {
  type    = string
  default = "docker-ms-app"
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
  default = ["docker-ms", "http-server", "docker"]
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
  default     = "stage"
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
  default = "docker-ms-app-ip"
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

```

- Изменяем значения переменных для контура stage:
/gcp/terraform/dev/terraform.tfvats

```t
project               = "immon4ik-infra"
public_key_path       = "~/otus/key/ssh/immon4ik-for-terraform.pub"
private_key_path      = "~/otus/key/ssh/immon4ik-for-terraform.pri"
disk_image            = "docker-ms-1587136740"
count_app             = "1"
health_check_port     = "8000"
hc_check_interval_sec = "1"
hc_timeout_sec        = "1"
label_env             = "stage"

```

- Переходим в папку контура stage. Форматируем синтаксис terraform. Инициализируем модули, проверяем возможность создания и собираем _хост с приложением от otus_:

```bash
cd stage
terraform init
terraform fmt
terraform plan
terraform apply --auto-approve

```

__Заходим в браузере, по адресу созданного хоста и проверяем работоспособность приложения: <http://iphost:8000>__

__В дополнение были созданы вспомогательные параметризированнные модули. Весь актуальный код можно найти в /gcp.__

[Карта выполнения проекта](#карта-выполнения-проекта)

</details>

------------------

#### Работаем с _управляющим хостом_ docker-ms.

<details>
  <summary>18.04.2020. docker-ms.</summary>

- Выполнена инициализация и вход в gcp. Для разграничения зон был создан отдельный проект immon4ik-docker.

```bash
gcloud init
gcloud auth login
gcloud auth list
gcloud auth application-default login
export GOOGLE_PROJECT=my_project

```

- Cинхронизации файлов windows хоста и _управляющего хоста_ настроена через плагин для vsc - SFTP - <https://github.com/liximomo/vscode-sftp.git>.

- Проверяем наличие необходимых правил firewall(80,443,8000) в проекте immon4ik-docker, при необходимости добавляем недостающие.

```bash
gcloud compute firewall-rules list

gcloud compute firewall-rules create docker-machine-allow-http \
  --allow tcp:80 \
  --target-tags=docker-machine \
  --description="Allow http connections" \
  --direction=INGRESS

gcloud compute firewall-rules create docker-machine-allow-https \
  --allow tcp:443 \
  --target-tags=docker-machine \
  --description="Allow https connections" \
  --direction=INGRESS

gcloud compute firewall-rules create rabbitmq \
  --allow tcp:8081 \
  --target-tags=docker-machine \
  --description="Allow RabbitMQ Mgmt connections" \
  --direction=INGRESS

gcloud compute firewall-rules create project-ui \
  --allow tcp:8000 \
  --target-tags=docker-machine \
  --description="Allow Project UI connections" \
  --direction=INGRESS

```

- Создан хост docker-gl используя docker-machine:

```bash
docker-machine create --driver google \
 --google-machine-image "ubuntu-os-cloud/global/images/ubuntu-1604-xenial-v20200407" \
 --google-disk-size "50" --google-disk-type "pd-standard" \
 --google-machine-type "n1-standard-1" --google-zone europe-west1-b docker-gl

```

- Переходим к работе с docker-gl.

```bash
eval $(docker-machine env docker-gl)

```

- Пишем сценарий установки Gitlab на хост docker-gl:  
gitlab-ci/docker-compose.yml

```yml
web:
  image: 'gitlab/gitlab-ce:latest'
  restart: always
  hostname: 'gitlab.example.com'
  environment:
    GITLAB_OMNIBUS_CONFIG: |
      external_url '${GITLAB_CI_URL:-http://127.0.0.1}'
  ports:
    - '80:80'
    - '443:443'
    - '2222:22'
  volumes:
    - '/srv/gitlab/config:/etc/gitlab'
    - '/srv/gitlab/logs:/var/log/gitlab'
    - '/srv/gitlab/data:/var/opt/gitlab'

```

- Поднимаем контейнер с GitLab CI на хосте docker-gitlab используя docker-compose:

```bash
export GITLAB_CI_URL=http://my_docker-gl_host_ip/
docker-machine ssh docker-gl sudo mkdir -p /srv/gitlab/config /srv/gitlab/data /srv/gitlab/logs
docker-compose -f ./gitlab-ci/docker-compose.yml config
docker-compose -f ./gitlab-ci/docker-compose.yml up -d

```

- Проверяем работу Gitlab CI - <http://my_docker-gl_host_ip/>. Регистрируем пароль root. Создаем группу\проект для билда-теста-деплоя-дестроя приложения от otus.

- Переходим в папку синхронизированную с windows хоста, создаем репо в Gitlab CI и пушим туда наши наработки:

```git
cd project
git remote add gitlab http://my_docker-gl_host_ip/my_group/my_project.git
git push gitlab gitlab-ci-otus-app

```

- Пишем скрипт, автоматизирующих запуск gitlab-runner на хосте. Т.к. планируется работа c __docker in docker(dind)__ учтена необходимость присутствие сертификатов. Для этого определены сертификаты хоста docker-gitlab и импортированы в переменные(*решение тестовое, не самое безопасное, вижу решение в монтировании volume с сертификатами MOUNT_POINT: /builds/$CI_PROJECT_PATH/mnt_*):  
/gitlab-ci/run_reg_runner.sh

```bash
#!/bin/bash
set -evx

# Переменные для успешного запуска gitlab-runner:
export GITLAB_CI_URL=http://my_docker-gl_host_ip/
export GITLAB_CI_TOKEN=my_gitlab_ci_token
export RUNNER_NAME=${RANDOM}-gitlab-runner

# Получение пересенных среды docker-gitlab:
docker-machine env docker-gl

# Добавление переменных с содержанием сертификатов:
export DOCKER_HOST_CA_FILE=$(cat $DOCKER_CERT_PATH/ca.pem)
export DOCKER_HOST_CERT_FILE=$(cat $DOCKER_CERT_PATH/cert.pem)
export DOCKER_HOST_KEY_FILE=$(cat $DOCKER_CERT_PATH/key.pem)

# Запускаем gitlab-runner:
docker run -d --name $RUNNER_NAME --restart always \
  -v /srv/${RUNNER_NAME}/config:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /home/docker-user/crt:/builds/homework/example \
  gitlab/gitlab-runner:latest

# Регистрируем и добавляем переменные сертификатов в запущенный gitlab-runner:
docker exec -it $RUNNER_NAME gitlab-runner register \
  --run-untagged \
  --locked=false \
  --non-interactive \
  --url ${GITLAB_CI_URL:-http://127.0.0.1} \
  --registration-token $GITLAB_CI_TOKEN \
  --description "docker-runner" \
  --tag-list "linux,xenial,ubuntu,docker" \
  --executor docker \
  --docker-image "alpine:latest" \
  --docker-privileged \
  --docker-volumes "docker-certs-client:/certs/client" \
  --env "DOCKER_DRIVER=overlay2" \
  --env "DOCKER_TLS_CERTDIR=/certs" \
  --env "DOCKER_HOST_CA_FILE=$(cat $DOCKER_CERT_PATH/ca.pem)" \
  --env "DOCKER_HOST_CERT_FILE=$(cat $DOCKER_CERT_PATH/cert.pem)" \
  --env "DOCKER_HOST_KEY_FILE=$(cat $DOCKER_CERT_PATH/key.pem)"

```

- Выполнен вход в dockerhub и регистрация переменных среды оружения для последующего пуша в личный dockerhub сбилженых образов приложения от otus.

```bash
export DOCKER_HUB_LOGIN=mylogin
export DOCKER_HUB_PASSWORD=mypassword
docker login -u $DOCKER_HUB_LOGIN -p $DOCKER_HUB_PASSWORD

```

- Интегрированы оповещения от Gitlab CI в мой канал slack(#pavel-batsev - <https://devops-team-otus.slack.com/archives/CRTMNFU4U>), используя встроенную интеграцию Gitlab и добавленное в канал slack приложение Incoming WebHooks.

- Пишем сценарий .gitlab-ci.yml для реализации билда образов и их пуша в мой dockerhub, теста-деплоя-дестроя приложения от otus с приминением dind:  
.gitlab-ci.yml

```yml
stages:
    - build
    - test
    - review
    - stage
    - production
build_job:
    stage: build
    image: 'docker:19.03.8'
    services:
        - 'docker:19.03.8-dind'
    before_script:
        - 'docker info'
        - 'docker login -u $DOCKER_HUB_LOGIN -p $DOCKER_HUB_PASSWORD'
        - 'docker image ls'
    script:
        - 'echo ''Building'''
        - 'docker build -t ${DOCKER_HUB_LOGIN:-user}/otus-app-ui:${CI_COMMIT_TAG:-1.0.0}.${CI_COMMIT_SHORT_SHA:-0} ./src/project-ui'
        - 'docker push ${DOCKER_HUB_LOGIN:-user}/otus-app-ui:${CI_COMMIT_TAG:-1.0.0}.${CI_COMMIT_SHORT_SHA:-0}'
        - 'docker build -t ${DOCKER_HUB_LOGIN:-user}/otus-app-crawler:${CI_COMMIT_TAG:-1.0.0}.${CI_COMMIT_SHORT_SHA:-0} ./src/project-crawler'
        - 'docker push ${DOCKER_HUB_LOGIN:-user}/otus-app-crawler:${CI_COMMIT_TAG:-1.0.0}.${CI_COMMIT_SHORT_SHA:-0}'
    after_script:
        - 'docker image ls'
test_unit_job:
    stage: test
    script:
        - 'echo ''Testing 1'''
test_integration_job:
    stage: test
    script:
        - 'echo ''Testing 2'''
deploy_dev_job:
    stage: review
    script:
        - 'echo ''Deploy on dev'''
    environment:
        name: dev
        url: 'http://dev.example.com'
branch_review:
    stage: review
    image: 'docker:19.03.8'
    variables:
        DOCKER_TLS_VERIFY: '1'
        DOCKER_HOST: 'tcp://$CI_SERVER_HOST:2376'
        DOCKER_CERT_PATH: /tmp/$CI_COMMIT_REF_NAME
        COMPOSE_PROJECT_NAME: $COMPOSE_PROJECT_NAME
        DOCKER_HUB_USERNAME: $DOCKER_HUB_USERNAME
        NETWORK_BACK_NET: $NETWORK_BACK_NET
        NETWORK_FRONT_NET: $NETWORK_FRONT_NET
        NETWORK_BACK_NET_DRIVER: $NETWORK_BACK_NET_DRIVER
        NETWORK_FRONT_NET_DRIVER: $NETWORK_FRONT_NET_DRIVER
        NETWORK_BACK_NET_SUBNET: $NETWORK_BACK_NET_SUBNET
        NETWORK_FRONT_NET_SUBNET: $NETWORK_FRONT_NET_SUBNET
        MONGO_DB_IMAGE: $MONGO_DB_IMAGE
        MONGO_DB_VOL_NAME: $MONGO_DB_VOL_NAME
        MONGO_DB_VOL_DEST: $MONGO_DB_VOL_DEST
        MONGO_DB_BACK_NET_ALIAS: $MONGO_DB_BACK_NET_ALIAS
        MONGO_DB_FRONT_NET_ALIAS: $MONGO_DB_FRONT_NET_ALIAS
        RABBIT_MQ_IMAGE: $RABBIT_MQ_IMAGE
        RABBIT_MQ_VOL_HOME_NAME: $RABBIT_MQ_VOL_HOME_NAME
        RABBIT_MQ_VOL_HOME_DEST: $RABBIT_MQ_VOL_HOME_DEST
        RABBIT_MQ_VOL_CONFIG_NAME: $RABBIT_MQ_VOL_CONFIG_NAME
        RABBIT_MQ_VOL_CONFIG_DEST: $RABBIT_MQ_VOL_CONFIG_DEST
        RABBIT_MQ_BACK_NET_ALIAS: $RABBIT_MQ_BACK_NET_ALIAS
        CRAWLER_BUILD_PATH: $CRAWLER_BUILD_PATH
        CRAWLER_IMAGE: $CRAWLER_IMAGE
        CRAWLER_IMAGE_VERSION: $CRAWLER_IMAGE_VERSION
        CRAWLER_VOL_NAME: $CRAWLER_VOL_NAME
        CRAWLER_VOL_DEST: $CRAWLER_VOL_DEST
        UI_BUILD_PATH: $UI_BUILD_PATH
        UI_IMAGE: $UI_IMAGE
        UI_IMAGE_VERSION: $UI_IMAGE_VERSION
        UI_VOL_NAME: $UI_VOL_NAME
        UI_VOL_DEST: $UI_VOL_DEST
        UI_PORT: $UI_PORT
    before_script:
        - 'mkdir -p $DOCKER_CERT_PATH'
        - 'echo "$DOCKER_HOST_CA_FILE" > $DOCKER_CERT_PATH/ca.pem'
        - 'echo "$DOCKER_HOST_CERT_FILE" > $DOCKER_CERT_PATH/cert.pem'
        - 'echo "$DOCKER_HOST_KEY_FILE" > $DOCKER_CERT_PATH/key.pem'
        - 'echo "DOCKER_CERT_PATH=$DOCKER_CERT_PATH"'
        - 'ls -a $DOCKER_CERT_PATH'
        - 'echo "DOCKER_HOST=$DOCKER_HOST"'
        - 'docker info'
        - 'docker login -u $DOCKER_HUB_LOGIN -p $DOCKER_HUB_PASSWORD'
        - 'apk add py-pip python-dev libffi-dev openssl-dev gcc libc-dev make'
        - 'pip install docker-compose'
        - 'docker-compose --version'
        - 'docker ps -as'
        - 'docker image ls'
        - 'source ./src/.env'
        - 'echo ${UI_PORT}'
        - 'docker-compose -f ./src/docker-compose.yml config'
    after_script:
        - 'docker ps -as'
        - 'docker image ls'
    only:
        - branches
    except:
        - master
    script:
        - 'echo "Deploy on branch/$CI_COMMIT_REF_NAME environment"'
        - 'docker-compose -f ./src/docker-compose.yml up -d'
    environment:
        name: branch/$CI_COMMIT_REF_NAME
        url: 'http://$CI_SERVER_HOST:8000'
        on_stop: stop_branch_review
        auto_stop_in: '3 days'
stop_branch_review:
    stage: review
    image: 'docker:19.03.8'
    variables:
        DOCKER_TLS_VERIFY: '1'
        DOCKER_HOST: 'tcp://$CI_SERVER_HOST:2376'
        DOCKER_CERT_PATH: /tmp/$CI_COMMIT_REF_NAME
        COMPOSE_PROJECT_NAME: $COMPOSE_PROJECT_NAME
        DOCKER_HUB_USERNAME: $DOCKER_HUB_USERNAME
        NETWORK_BACK_NET: $NETWORK_BACK_NET
        NETWORK_FRONT_NET: $NETWORK_FRONT_NET
        NETWORK_BACK_NET_DRIVER: $NETWORK_BACK_NET_DRIVER
        NETWORK_FRONT_NET_DRIVER: $NETWORK_FRONT_NET_DRIVER
        NETWORK_BACK_NET_SUBNET: $NETWORK_BACK_NET_SUBNET
        NETWORK_FRONT_NET_SUBNET: $NETWORK_FRONT_NET_SUBNET
        MONGO_DB_IMAGE: $MONGO_DB_IMAGE
        MONGO_DB_VOL_NAME: $MONGO_DB_VOL_NAME
        MONGO_DB_VOL_DEST: $MONGO_DB_VOL_DEST
        MONGO_DB_BACK_NET_ALIAS: $MONGO_DB_BACK_NET_ALIAS
        MONGO_DB_FRONT_NET_ALIAS: $MONGO_DB_FRONT_NET_ALIAS
        RABBIT_MQ_IMAGE: $RABBIT_MQ_IMAGE
        RABBIT_MQ_VOL_HOME_NAME: $RABBIT_MQ_VOL_HOME_NAME
        RABBIT_MQ_VOL_HOME_DEST: $RABBIT_MQ_VOL_HOME_DEST
        RABBIT_MQ_VOL_CONFIG_NAME: $RABBIT_MQ_VOL_CONFIG_NAME
        RABBIT_MQ_VOL_CONFIG_DEST: $RABBIT_MQ_VOL_CONFIG_DEST
        RABBIT_MQ_BACK_NET_ALIAS: $RABBIT_MQ_BACK_NET_ALIAS
        CRAWLER_BUILD_PATH: $CRAWLER_BUILD_PATH
        CRAWLER_IMAGE: $CRAWLER_IMAGE
        CRAWLER_IMAGE_VERSION: $CRAWLER_IMAGE_VERSION
        CRAWLER_VOL_NAME: $CRAWLER_VOL_NAME
        CRAWLER_VOL_DEST: $CRAWLER_VOL_DEST
        UI_BUILD_PATH: $UI_BUILD_PATH
        UI_IMAGE: $UI_IMAGE
        UI_IMAGE_VERSION: $UI_IMAGE_VERSION
        UI_VOL_NAME: $UI_VOL_NAME
        UI_VOL_DEST: $UI_VOL_DEST
        UI_PORT: $UI_PORT
    before_script:
        - 'mkdir -p $DOCKER_CERT_PATH'
        - 'echo "$DOCKER_HOST_CA_FILE" > $DOCKER_CERT_PATH/ca.pem'
        - 'echo "$DOCKER_HOST_CERT_FILE" > $DOCKER_CERT_PATH/cert.pem'
        - 'echo "$DOCKER_HOST_KEY_FILE" > $DOCKER_CERT_PATH/key.pem'
        - 'echo "DOCKER_CERT_PATH=$DOCKER_CERT_PATH"'
        - 'ls -a $DOCKER_CERT_PATH'
        - 'echo "DOCKER_HOST=$DOCKER_HOST"'
        - 'docker info'
        - 'docker login -u $DOCKER_HUB_LOGIN -p $DOCKER_HUB_PASSWORD'
        - 'apk add py-pip python-dev libffi-dev openssl-dev gcc libc-dev make'
        - 'pip install docker-compose'
        - 'docker-compose --version'
        - 'docker ps -as'
        - 'docker image ls'
        - 'source ./src/.env'
        - 'echo ${UI_PORT}'
        - 'docker-compose -f ./src/docker-compose.yml config'
    after_script:
        - 'docker ps -as'
        - 'docker image ls'
    only:
        - branches
    except:
        - master
    when: manual
    script:
        - 'echo ''Remove branch review app'''
        - 'docker-compose -f ./src/docker-compose.yml down'
        - 'docker image rm -f $(docker image ls -q ${DOCKER_HUB_LOGIN:-user}/otus-app-ui) || echo'
        - 'docker image rm -f $(docker image ls -q ${DOCKER_HUB_LOGIN:-user}/otus-app-crawler) || echo'
        - 'docker image rm -f $(docker image ls -q --filter ''dangling=true'') || echo'
    environment:
        name: branch/$CI_COMMIT_REF_NAME
        action: stop
staging:
    stage: stage
    when: manual
    only:
        - /^\d+\.\d+\.\d+/
    script:
        - 'echo ''Deploy on stage'''
    environment:
        name: stage
        url: 'https://beta.example.com'
production:
    stage: production
    when: manual
    only:
        - /^\d+\.\d+\.\d+/
    script:
        - 'echo ''Deploy on production'''
    environment:
        name: production
        url: 'https://example.com'

```

- Выполняем коммит в репо Gitlab CI и проверяем результат. В браузре открываем <http://my_docker-gl_host_ip:8000>. Полезные команды диагностики:

```bash
docker-compose ps
docker-compose logs $(docker-compose ps -aq)

```

__(_В основе своей проектная стадия для mvp завершена._)__  
__В следующей части будет добавлено тестирование, мониторинг, логирование. Доработаны\автоматизированы процессы разворачивания инфраструктуры и приложения. Т.к. разработка и документация ведётся в одиночку, то в зависимости от сроков, для оркестрации контейнеров планируется использовать kuber.__

[Карта выполнения проекта](#карта-выполнения-проекта)

</details>

------------------

### 10.05.2020.

#### Настройка процесса сбора обратной связи.

<details>
  <summary>10.05.2020. Настройка процесса сбора обратной связи.</summary>

- Внедрим unit тестирование crawler и ui. Для этого доработаем gitlab-ci.yml:

```yml
[...]
test_unit_job_ui:
    stage: test
    image: 'python:3.8.2-alpine'
    services:
        - 'python:3.8.2-alpine'
    before_script:
        - 'cd src/project-ui/ && pip install -r requirements.txt -r requirements-test.txt'
    script:
        - 'echo ''Testing otus-app-ui'''
        - 'python -m unittest discover -s tests/'
        - 'coverage run -m unittest discover -s tests/'
        - 'coverage report --include ui/ui.py'
test_unit_job_crawler:
    stage: test
    image: 'python:3.6.0-alpine'
    services:
        - 'python:3.6.0-alpine'
    before_script:
        - 'cd src/project-crawler/ && pip install -r requirements.txt -r requirements-test.txt'
    script:
        - 'echo ''Testing otus-app-crawler'''
        - 'python -m unittest discover -s tests/'
        - 'coverage run -m unittest discover -s tests/'
        - 'coverage report --include crawler/crawler.py'
[...]

```

__Добавим мониторинг\логирование\трейсинг в наш проект. Для этого создадим в корне репо каталог monlog и добавим в него наши наработки из домашних заданий, кастомизировав их согласно потребностям моего проекта:__

- В каталогах микросрвсов создадим скрипты сборки docker_build.sh по следующему типу:

```bash
#!/bin/bash
set -eu

docker build -t $DOCKER_HUB_LOGIN/fluentd:prj .

```

- В корне репо для упрощения реализации создадим Makefile и сформируем его согласно потребностям моего проекта:

```makefile
APP_IMAGES := project-ui project-crawler rabbitmq
MON_IMAGES := rabbitmq_exporter mongodb_exporter cloudprober_exporter alertmanager telegraf grafana prometheus
LOG_IMAGES := fluentd
DOCKER_COMMANDS := build push imgrm
COMPOSE_COMMANDS := config up down logs
COMPOSE_COMMANDS_MON := configmon upmon downmon logsmon
COMPOSE_COMMANDS_LOG := configlog uplog downlog
COMPOSE_COMMANDS_DEL := downall

ifeq '$(strip $(DOCKER_HUB_LOGIN))' ''
  $(warning Variable DOCKER_HUB_LOGIN is not defined, using value 'user')
  DOCKER_HUB_LOGIN := immon
endif

ENV_APP_FILE := $(shell echo 'src/.env_gl')
ENV_MONLOG_FILE := $(shell echo 'monlog/.env_gl')
ENV_DEL_FILE := $(shell echo '.env_del_gl')

bsgl:
 bash before_script.sh; cd -

build: $(APP_IMAGES) $(MON_IMAGES) $(LOG_IMAGES)

$(APP_IMAGES):
 cd -; cd src/$@; bash docker_build_gl.sh; cd -

$(MON_IMAGES):
 cd -; cd monlog/monitoring/$@; bash docker_build_gl.sh; cd -; cd -

$(LOG_IMAGES):
 cd -; cd monlog/logging/$@; bash docker_build_gl.sh; cd -; cd -

push:
ifneq '$(strip $(DOCKER_HUB_PASSWORD))' ''
 @docker login -u $(DOCKER_HUB_LOGIN) -p $(DOCKER_HUB_PASSWORD)
 $(foreach i,$(APP_IMAGES) $(MON_IMAGES) $(LOG_IMAGES),docker push $(DOCKER_HUB_LOGIN)/$(i);)
else
 @echo 'Variable DOCKER_HUB_PASSWORD is not defined, cannot push images'
endif

imgrm:
 @echo "Remove all non running containers"
 -docker rm `docker ps -q -f status=exited`
 @echo "Delete all untagged/dangling (<none>) images"
 -docker rmi `docker images -q -f dangling=true`

$(COMPOSE_COMMANDS):
 cd -; docker-compose --env-file $(ENV_APP_FILE) -f src/docker-compose-gl.yml $(subst up,up -d,$@)

$(COMPOSE_COMMANDS_MON):
 cd -; docker-compose --env-file $(ENV_MONLOG_FILE) -f monlog/docker-compose-monitoring-gl.yml $(subst mon,,$(subst up,up -d,$@))

$(COMPOSE_COMMANDS_LOG):
 cd -; docker-compose --env-file $(ENV_MONLOG_FILE) -f monlog/docker-compose-logging-gl.yml $(subst log,,$(subst up,up -d,$@))

$(COMPOSE_COMMANDS_DEL):
 docker-compose --env-file $(ENV_DEL_FILE) -f docker-compose-del-gl.yml $(subst all,,$(subst up,up -d,$@)) -v

$(APP_IMAGES) $(MON_IMAGES) $(DOCKER_COMMANDS) $(COMPOSE_COMMANDS) $(COMPOSE_COMMANDS_MON) $(COMPOSE_COMMANDS_LOG) $(COMPOSE_COMMANDS_DEL): FORCE

FORCE:

```

- В процессе внедрения мониторинга\логирования\трейсинаг доработаны множество инструментов, с полным списком можно ознакомиться в каталоге monlog.

[Карта выполнения проекта](#карта-выполнения-проекта)

</details>

------------------

### 11.05.2020.

#### Доработка конвейера Gitlab CI.

<details>
  <summary>11.05.2020. Доработка конвейера Gitlab CI.</summary>

- Реализация всех компонентов проекта приложение\мониторинг\логирование планируется на одном хосте, поэтому добавлены ресурсы для хоста docker-gl.

- Согласно рекомендациям от куратора проекта доработан .gitlab-ci.yml:

```yml
stages:
    - build
    - test
    - review
    - stage
    - production
build_job:
    stage: build
    image: 'docker:19.03.8'
    services:
        - 'docker:19.03.8-dind'
    before_script:
        - 'docker info'
        - 'apk add make && apk add bash'
    script:
        - 'echo ''Building'''
        - 'cd gitlab-ci && ls && make build && make push'
    after_script:
        - 'docker image ls'
test_unit_job_ui:
    stage: test
    image: 'python:3.8.2-alpine'
    services:
        - 'python:3.8.2-alpine'
    before_script:
        - 'cd src/project-ui/ && pip install -r requirements.txt -r requirements-test.txt'
    script:
        - 'echo ''Testing otus-app-ui'''
        - 'python -m unittest discover -s tests/'
        - 'coverage run -m unittest discover -s tests/'
        - 'coverage report --include ui/ui.py'
test_unit_job_crawler:
    stage: test
    image: 'python:3.6.0-alpine'
    services:
        - 'python:3.6.0-alpine'
    before_script:
        - 'cd src/project-crawler/ && pip install -r requirements.txt -r requirements-test.txt'
    script:
        - 'echo ''Testing otus-app-crawler'''
        - 'python -m unittest discover -s tests/'
        - 'coverage run -m unittest discover -s tests/'
        - 'coverage report --include crawler/crawler.py'
test_integration_job:
    stage: test
    script:
        - 'echo ''Testing 2'''
deploy_dev_job:
    stage: review
    script:
        - 'echo ''Deploy on dev'''
    environment:
        name: dev
        url: 'http://dev.example.com'
branch_review:
    stage: review
    image: 'docker:19.03.8'
    variables:
        DOCKER_TLS_VERIFY: '1'
        DOCKER_HOST: 'tcp://$CI_SERVER_HOST:2376'
        DOCKER_CERT_PATH: /tmp/$CI_COMMIT_REF_NAME
    before_script:
        - 'apk add make && apk add bash'
        - 'cd gitlab-ci && make bsgl'
    after_script:
        - 'docker ps -as'
        - 'docker image ls'
    only:
        - branches
    except:
        - master
    script:
        - 'echo "Deploy on branch/$CI_COMMIT_REF_NAME environment"'
        - 'ls && make up && make upmon'
    environment:
        name: branch/$CI_COMMIT_REF_NAME
        url: 'http://$CI_SERVER_HOST:8000'
        on_stop: stop_branch_review
        auto_stop_in: '3 days'
stop_branch_review:
    stage: review
    image: 'docker:19.03.8'
    variables:
        DOCKER_TLS_VERIFY: '1'
        DOCKER_HOST: 'tcp://$CI_SERVER_HOST:2376'
        DOCKER_CERT_PATH: /tmp/$CI_COMMIT_REF_NAME
    before_script:
        - 'apk add make && apk add bash'
        - 'cd gitlab-ci && make bsgl'
    after_script:
        - 'docker ps -as'
        - 'docker image ls'
    only:
        - branches
    except:
        - master
    when: manual
    script:
        - 'echo ''Remove branch review app'''
        - 'ls && make downall && make imgrm'
    environment:
        name: branch/$CI_COMMIT_REF_NAME
        action: stop
staging:
    stage: stage
    when: manual
    only:
        - /^\d+\.\d+\.\d+/
    script:
        - 'echo ''Deploy on stage'''
    environment:
        name: stage
        url: 'https://beta.example.com'
production:
    stage: production
    when: manual
    only:
        - /^\d+\.\d+\.\d+/
    script:
        - 'echo ''Deploy on production'''
    environment:
        name: production
        url: 'https://example.com'

```

[Карта выполнения проекта](#карта-выполнения-проекта)

</details>

------------------

### 12.05.2020.

#### Доработка конвейера Gitlab CI.

<details>
  <summary>12.05.2020. Доработка конвейера Gitlab CI.</summary>

- Для удаления всех контейнеров\сетей\волюмов\образов написан общий параметризированный сценарий для docker-compose:

gitlab-ci/docker-compose-del-gl.yml

```yml
version: '3.8'
services:
  mongo_db:
    image: ${MONGO_DB_IMAGE}
    volumes:
      - ${MONGO_DB_VOL_NAME}:${MONGO_DB_VOL_DEST}
    networks:
        back_net:
            aliases:
                - ${MONGO_DB_BACK_NET_ALIAS}
        front_net:
            aliases:
                - ${MONGO_DB_FRONT_NET_ALIAS}
  rabbit_mq:
    depends_on:
      - mongo_db
    image: ${DOCKER_HUB_USERNAME}/${RABBIT_MQ_IMAGE}:${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}
    volumes:
      - ${RABBIT_MQ_VOL_HOME_NAME}:${RABBIT_MQ_VOL_HOME_DEST}
      - ${RABBIT_MQ_VOL_CONFIG_NAME}:${RABBIT_MQ_VOL_CONFIG_DEST}
    ports:
      - ${RABBIT_MQ_PORT}:${RABBIT_MQ_PORT}/tcp
      - '8081:15672'
      - '5672:5672'
    networks:
      back_net:
        aliases:
          - ${RABBIT_MQ_BACK_NET_ALIAS}
  crawler:
    environment:
      - ZIPKIN_ENABLED=${ZIPKIN_ENABLED}
    depends_on:
      - rabbit_mq
    image: ${DOCKER_HUB_USERNAME}/${CRAWLER_IMAGE}:${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}
    volumes:
      - ${CRAWLER_VOL_NAME}:${CRAWLER_VOL_DEST}
    networks:
      - ${NETWORK_BACK_NET}
    logging:
      driver: 'fluentd'
      options:
        fluentd-address: localhost:24224
        tag: service.crawler
  ui:
    environment:
      - ZIPKIN_ENABLED=${ZIPKIN_ENABLED}
    depends_on:
      - crawler
    image: ${DOCKER_HUB_USERNAME}/${UI_IMAGE}:${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}
    volumes:
      - ${UI_VOL_NAME}:${UI_VOL_DEST}
    ports:
      - ${UI_PORT}:${UI_PORT}/tcp
    networks:
      - ${NETWORK_FRONT_NET}
    logging:
      driver: 'fluentd'
      options:
        fluentd-address: localhost:24224
        tag: service.ui
  fluentd:
    image: ${DOCKER_HUB_USERNAME}/fluentd:${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}
    ports:
      - '24224:24224'
      - '24224:24224/udp'
    networks:
      - ${NETWORK_FRONT_NET}
      - ${NETWORK_BACK_NET}
  prometheus:
    image: ${DOCKER_HUB_USERNAME}/prometheus:${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}
    ports:
      - '9090:9090'
    volumes:
      - prometheus_data:/prometheus
    networks:
      - ${NETWORK_BACK_NET}
      - ${NETWORK_FRONT_NET}
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention=1d'
  node-exporter:
    image: prom/node-exporter:latest
    user: root
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    networks:
      - ${NETWORK_BACK_NET}
      - ${NETWORK_FRONT_NET}
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.ignored-mount-points="^/(sys|proc|dev|host|etc)($$|/)"'
  mongodb_exporter:
    image: ${DOCKER_HUB_USERNAME}/mongodb_exporter:${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}
    environment:
      - MONGODB_URI=${MONGODB_URI}
    ports:
      - '9216:9216'
    networks:
      - ${NETWORK_BACK_NET}
  rabbitmq_exporter:
    image: ${DOCKER_HUB_USERNAME}/rabbitmq_exporter:${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}
    # environment: 
    #   - RABBITMQ_NODENAME=crawler_mq
    networks:
      - ${NETWORK_BACK_NET}
      - ${NETWORK_FRONT_NET}
  cloudprober_exporter:
    image: ${DOCKER_HUB_USERNAME}/cloudprober_exporter:${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}
    ports:
      - '9313:9313'
    networks:
      - ${NETWORK_BACK_NET}
      - ${NETWORK_FRONT_NET}
  cadvisor:
    image: google/cadvisor:${CADVISOR_VERSION}
    volumes:
      - '/:/rootfs:ro'
      - '/var/run:/var/run:rw'
      - '/sys:/sys:ro'
      - '/var/lib/docker/:/var/lib/docker:ro'
    ports:
      - '8080:8080'
    networks:
        - ${NETWORK_FRONT_NET}
  grafana:
    image: ${DOCKER_HUB_USERNAME}/grafana:${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=secret
    depends_on:
      - prometheus
    ports:
      - 3000:3000
    networks:
      - ${NETWORK_BACK_NET}
      - ${NETWORK_FRONT_NET}
  alertmanager:
    image: ${DOCKER_HUB_USERNAME}/alertmanager:${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}
    command:
      - '--config.file=/etc/alertmanager/config.yml'
    ports:
      - 9093:9093
    networks:
      - ${NETWORK_BACK_NET}
      - ${NETWORK_FRONT_NET}
  telegraf:
    depends_on:
      - influxdb
    image: ${DOCKER_HUB_USERNAME}/telegraf:${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}
    environment: 
      - USER="telegraf"
      - INFLUX_URL="http://influxdb:8086"
      - INFLUX_SKIP_DATABASE_CREATION="true"
      - INFLUX_PASSWORD="telegraf"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - ${NETWORK_BACK_NET}
      - ${NETWORK_FRONT_NET}
  influxdb:
    image: influxdb
    volumes:
      - influxdb_data:/var/lib/influxdb
    ports:
      - 8086:8086
    networks:
      - ${NETWORK_BACK_NET}
      - ${NETWORK_FRONT_NET}
  elasticsearch:
    image: elasticsearch:7.6.2
    environment:
      - 'discovery.type=single-node'
    volumes:
      - elasticsearch_data:/usr/share/elasticsearch/data
    expose:
      - 9200
    ports:
      - '9200:9200'
    networks:
      - ${NETWORK_BACK_NET}
      - ${NETWORK_FRONT_NET}
  kibana:
    image: kibana:7.6.2
    ports:
      - '5601:5601'
    networks:
      - ${NETWORK_BACK_NET}
      - ${NETWORK_FRONT_NET}
  zipkin:
    image: openzipkin/zipkin
    ports:
      - '9411:9411'
    networks:
      - ${NETWORK_BACK_NET}
      - ${NETWORK_FRONT_NET}

volumes:
  db_crawler:
  mq_rabbit_home:
  mq_rabbit_config:
  bot_crawler:
  app_ui:
  prometheus_data:
  grafana_data:
  influxdb_data:
  elasticsearch_data:

networks:
  back_net:
    driver: ${NETWORK_BACK_NET_DRIVER}
    ipam:
      driver: default
      config:
        - subnet: ${NETWORK_BACK_NET_SUBNET}
  front_net:
    driver: ${NETWORK_FRONT_NET_DRIVER}
    ipam:
      driver: default
      config:
        - subnet: ${NETWORK_FRONT_NET_SUBNET}

```

gitlab-ci/.env_del_gl

```env
# Общие переменные среды всего проекта.
COMPOSE_PROJECT_NAME=immon4ik_project
DOCKER_HUB_USERNAME=immon
NETWORK_BACK_NET=back_net
NETWORK_FRONT_NET=front_net
NETWORK_BACK_NET_DRIVER=bridge
NETWORK_FRONT_NET_DRIVER=bridge
NETWORK_BACK_NET_SUBNET=10.0.5.0/24
NETWORK_FRONT_NET_SUBNET=10.0.4.0/24

# Переменные среды окружения mongo_db.
MONGO_DB_IMAGE=mongo:latest
MONGO_DB_VOL_NAME=db_crawler
MONGO_DB_VOL_DEST=/data/db
MONGO_DB_BACK_NET_ALIAS=crawler_db
MONGO_DB_FRONT_NET_ALIAS=ui_db

# Переменные среды окружения rabbit_mq.
RABBIT_MQ_IMAGE=rabbitmq
RABBIT_MQ_IMAGE_VERSION=${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}
RABBIT_MQ_VOL_HOME_NAME=mq_rabbit_home
RABBIT_MQ_VOL_HOME_DEST=/var/lib
RABBIT_MQ_VOL_CONFIG_NAME=mq_rabbit_config
RABBIT_MQ_VOL_CONFIG_DEST=/etc/rabbitmq
RABBIT_MQ_PORT=9419
RABBIT_MQ_BACK_NET_ALIAS=crawler_mq

# Переменные среды окружения crawler.
CRAWLER_BUILD_PATH=./project-crawler
CRAWLER_IMAGE=project-crawler
CRAWLER_IMAGE_VERSION=${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}
CRAWLER_VOL_NAME=bot_crawler
CRAWLER_VOL_DEST=/app

# Переменные среды окружения ui.
UI_BUILD_PATH=./project-ui
UI_IMAGE=project-ui
UI_IMAGE_VERSION=${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}
UI_VOL_NAME=app_ui
UI_VOL_DEST=/app
UI_PORT=8000

ZIPKIN_ENABLED=true

FLUENTD_VERSION=${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}

PROMETHEUS_VERSION=${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}

MONGODB_EXPORTER_VERSION=${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}
MONGODB_URI=mongodb://crawler_db:27017

RABBIT_URL=http://crawler_mq:15672
RABBITMQ_EXPORTER_VERSION=${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}

CLOUDPROBER_EXPORTER_VERSION=${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}

CADVISOR_VERSION=latest

GRAFANA_VERSION=${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}

ALERTMANAGER_VERSION=${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}

TELEGRAF_VERSION=${CI_COMMIT_TAG:-2.2.0}.${CI_COMMIT_SHORT_SHA:-0}

```

[Карта выполнения проекта](#карта-выполнения-проекта)

</details>

------------------

### Как работать с проектом и как его запустить.

#### Основы работы с проектом.

- В предыдущих частях raedme было описано, как создать инфраструктуру для работы с проектом. Примем за исходные данные то, что создан управляющий хост docker-ms, поднята докер-машина docker-gl, развернут Gitlab CI.

- Для наглядности и моего личного удобства, в работе будут использованы vsc, sourcetree, chrome.

[Карта выполнения проекта](#карта-выполнения-проекта)

#### Как поднять проект, используя docker-compose.

<details>
  <summary>docker-compose.</summary>

- Из терминала vsc подключаемся к управляющему хосту docker-ms:

```bash
ssh immon4ik@35.233.83.124

```

- Перходим в папку проекта:

```bash
cd ~/otus/project/

```

[Карта выполнения проекта](#карта-выполнения-проекта)

</details>

------------------
