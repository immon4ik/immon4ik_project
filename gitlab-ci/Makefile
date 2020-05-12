APP_IMAGES := project-ui project-crawler rabbitmq
MON_IMAGES := rabbitmq_exporter mongodb_exporter cloudprober_exporter alertmanager telegraf grafana prometheus
LOG_IMAGES := fluentd
DOCKER_COMMANDS := build push imgrm
COMPOSE_COMMANDS := config up down logs
COMPOSE_COMMANDS_MON := configmon upmon downmon logsmon
COMPOSE_COMMANDS_LOG := configlg uplg downlg logslg
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
	cd -; docker-compose --env-file $(ENV_MONLOG_FILE) -f monlog/docker-compose-logging-gl.yml $(subst lg,,$(subst up,up -d,$@))

$(COMPOSE_COMMANDS_DEL):
	docker-compose --env-file $(ENV_DEL_FILE) -f docker-compose-del-gl.yml $(subst all,,$(subst up,up -d,$@)) -v

$(APP_IMAGES) $(MON_IMAGES) $(DOCKER_COMMANDS) $(COMPOSE_COMMANDS) $(COMPOSE_COMMANDS_MON) $(COMPOSE_COMMANDS_LOG) $(COMPOSE_COMMANDS_DEL): FORCE

FORCE:
