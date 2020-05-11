FROM fluent/fluentd:v1.10

USER root

RUN gem install fluent-plugin-elasticsearch --no-document --version 4.0.7 && \
    gem install fluent-plugin-grok-parser --no-document --version 2.6.1 && \
    gem install fluent-plugin-concat --no-document --version 2.4.0

COPY fluent.conf /fluentd/etc/

USER fluent
