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

```bash
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

```bash
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

------------------

__16.04.2020. Написание сценариев подключения к gcp. Упаковка образа и сборка _управляющего хоста_ с установленным docker, docker-compose, docker-machine на базе centos8. Применение packer, ansible и terraform.__

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

- Установлены дополнения для vsc, сгенерырованы и добавлены ssh ключи. Выполнена регистрация и инициализация в gcp - <https://cloud.google.com/?hl=RU>, создан проект в gcp для управляющего хоста на базе centos8, создан сервисный аккаунт, скачан json-ключ. Полезный пул комманд:

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

- Запускаем проверку и создание образа:

```bash
packer validate -var-file=packer/variables.json packer/docker-ms.json
```
