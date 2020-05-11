APP_IMAGES := project-ui project-crawler rabbitmq
MON_IMAGES := rabbitmq_exporter prometheus mongodb_exporter cloudprober_exporter alertmanager telegraf grafana
LOG_IMAGES := fluentd
DOCKER_COMMANDS := build push imgrm
COMPOSE_COMMANDS := config up down logs
COMPOSE_COMMANDS_MON := configmon upmon downmon logsmon
COMPOSE_COMMANDS_LOG := configlog uplog downlog

ifeq '$(strip $(DOCKER_HUB_LOGIN))' ''
  $(warning Variable DOCKER_HUB_LOGIN is not defined, using value 'user')
  DOCKER_HUB_LOGIN := immon
endif

ENV_APP_FILE := $(shell test -f src/.env && echo 'src/.env')
ENV_MONLOG_FILE := $(shell test -f monlog/.env && echo 'monlog/.env')

glbs:
	cd gitlab-ci;  bash before_script.sh; cd -

build: $(APP_IMAGES) $(MON_IMAGES) $(LOG_IMAGES)

$(APP_IMAGES):
	cd src/$@; bash docker_build.sh; cd -

$(MON_IMAGES):
	cd monlog/monitoring/$@; bash docker_build.sh; cd -; cd -

$(LOG_IMAGES):
	cd monlog/logging/$@; bash docker_build.sh; cd -; cd -

push:
ifneq '$(strip $(DOCKER_HUB_PASSWORD))' ''
	@docker login -u $(DOCKER_HUB_LOGIN) -p $(DOCKER_HUB_PASSWORD)
	$(foreach i,$(APP_IMAGES) $(MON_IMAGES) $(LOG_IMAGES),docker push $(DOCKER_HUB_LOGIN)/$(i);)
else
	@echo 'Variable DOCKER_HUB_PASSWORD is not defined, cannot push images'
endif

$(COMPOSE_COMMANDS):
	docker-compose --env-file $(ENV_APP_FILE) -f src/docker-compose.yml $(subst up,up -d,$@)

$(COMPOSE_COMMANDS_MON):
	docker-compose --env-file $(ENV_MONLOG_FILE) -f monlog/docker-compose-monitoring.yml $(subst mon,,$(subst up,up -d,$@))

$(COMPOSE_COMMANDS_LOG):
	docker-compose --env-file $(ENV_MONLOG_FILE) -f monlog/docker-compose-logging.yml $(subst log,,$(subst up,up -d,$@))

$(APP_IMAGES) $(MON_IMAGES) $(DOCKER_COMMANDS) $(COMPOSE_COMMANDS) $(COMPOSE_COMMANDS_MON) $(COMPOSE_COMMANDS_LOG): FORCE

FORCE:
