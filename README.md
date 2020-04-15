# immon4ik_project

------------------

__Основной задачей проекта является закрепить практику по курсу.__

<!-- Поднятие хоста с помощью docker-machine для тестирования работ приложения от otus -->
```
export GOOGLE_PROJECT=my_project
docker-machine create --driver google \
 --google-machine-image "ubuntu-os-cloud/global/images/ubuntu-1604-xenial-v20200407" \
 --google-disk-size "50" --google-disk-type "pd-standard" \
 --google-machine-type "n1-standard-1" --google-zone europe-west1-b docker-project

```

<!-- Для проверки работы добавляем правило firewall созданному хосту docker-project -->
```
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

<!-- Переходим к работе с docker-project -->
```
eval $(docker-macine env docker-project)

```

<!-- Создадим две сети docker -->
```
docker network create back_net --subnet=10.0.2.0/24
docker network create front_net --subnet=10.0.1.0/24

```

<!-- Запустим котейнер mongodb в подсети back_net -->
```
docker run -d --network=back_net --name mongo_db \
 --network-alias=crawler_db mongo:latest

```

<!-- Подключем mongodb к сети front_net -->
```
docker network connect --alias ui_db front_net mongo_db

```

<!-- Запустим контейнер rabbitmq в подсети back_net -->
```
# Проброшен порт в консоль управления.
docker run -d --network=back_net -p 8081:15672 --hostname my_rabbit_mq --name rabbit_mq \
 --network-alias=crawler_mq --network-alias=ui_mq rabbitmq:3-management

# Без консоли управления.
docker run -d --network=back_net --hostname my_rabbit_mq --name rabbit_mq \
 --network-alias=crawler_mq --network-alias=ui_mq rabbitmq:3.8.3-alpine

```

<!-- Входим в dockerhub для билда в него образов -->
docker login -u mylogin -p mypass

<!-- Пробуем собрать образ для project-crawler -->
src/project-crawler/Dockerfile:
```
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

<!-- Пишем docker-entrypoint.sh для контейнера crawler -->
```
#!/bin/sh
set -e

sleep 5
python3 -u crawler/crawler.py https://vitkhab.github.io/search_engine_test_site/

```

<!-- Билдим образ crawler в свой docker hub -->
```
docker build -t immon/project-crawler:1.0 ./project-crawler

```

<!-- Запустим контейнер с crawler в сети back_net -->
```
docker run -d --network=back_net --name crawler --restart always \
 --network-alias=crawler immon/project-crawler:1.0

```

<!-- Пишем Dockerfile билда образ для контейнера ui -->
src/project-ui/Dockerfile:
```
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

<!-- Пишем docker-entrypoint.sh для контейнера ui -->
```
#!/bin/sh
set -e

cd ui && gunicorn ui:app -b 0.0.0.0

```

<!-- Билдим образ project-ui в свой docker hub -->
```
docker build -t immon/project-ui:1.0 ./project-ui

```

<!-- Запустим контейнер с crawler в сети front_net -->
```
docker run -d --network=front_net -p 8000:8000 --name ui --restart always \
 --network-alias=ui immon/project-ui:1.0

```
