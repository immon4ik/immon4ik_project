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
