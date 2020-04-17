# immon4ik_project

------------------

__Основной задачей проекта является закрепить практику по курсу.__

------------------

__15.04.2020. Создание образов контейнеров, сценария запуска приложения от otus. Проверка работы приложения.__

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
RUN ln -s usr/local/bin/docker-entrypoint.sh / # backwards compat

ENTRYPOINT ["docker-entrypoint.sh"]

```

- Пишем docker-entrypoint.sh для контейнера crawler.

```bash
#!/bin/sh
set -e

sleep 5
python3 -u crawler/crawler.py https://vitkhab.github.io/search_engine_test_site/

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
FROM python:3.6.0-alpine

WORKDIR /app
COPY . /app

RUN apk --no-cache --update add build-base=0.4-r1 \
    && pip install -r /app/requirements.txt \
    && apk del build-base

ENV MONGO ui_db
ENV MONGO_PORT 27017
ENV FLASK_APP ui.py

RUN chmod +x docker-entrypoint.sh
COPY docker-entrypoint.sh /usr/local/bin/
RUN ln -s usr/local/bin/docker-entrypoint.sh / # backwards compat

ENTRYPOINT ["docker-entrypoint.sh"]

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
DOCKER_HUB_USERNAME=myuser
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
CRAWLER_IMAGE_VERSION=3.1
CRAWLER_VOL_NAME=bot_crawler
CRAWLER_VOL_DEST=/app

# Переменные среды окружения ui.
UI_BUILD_PATH=./project-ui
UI_IMAGE=project-ui
UI_IMAGE_VERSION=2.0
UI_VOL_NAME=app_ui
UI_VOL_DEST=/app
UI_PORT=8000

USERNAME=myuser
UI_PORT=8000
UI_VERSION=2.0
POST_VERSION=2.0
COMMENT_VERSION=2.0

```

------------------

__16.04.2020. Написание сценариев подключения к gcp. Упаковка образа и сборка _управляющего хоста_ с установленным docker, docker-compose, docker-machine на базе imubuntu-1604-lts. Применение packer, ansible и terraform.__

- Для выполнения проекта используется хост:

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

__Работы ведутся в инраструктурном проекте gcp - immon4ik-infra.__

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

- Работаем с хостом сборки myhost. Выполнена инициализация и вход в gcp. Для синхронизации файлов на хосте сборки и windows хоста настроен плагин для vsc - SFTP - <https://github.com/liximomo/vscode-sftp.git>:  
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

------------------

__17.04.2020. Доработка плейбука ansible для установки docker, docker-compose, docker-machine.__  

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
