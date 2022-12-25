SHELL:=/bin/bash
VERSION := "v5.1.0"
DB_VERSION_UPGRADE_11_14 := v11-v14
BUILDDATE := $(shell TZ=UTC date +%Y-%m-%dT%H:%M:%SZ)
PROXY_EXISTS := $(shell if [[ "${https_proxy}" || "${http_proxy}" ]]; then echo 1; else echo 0; fi)
DOCKER_PROXY_FLAGS := ""
ifeq ($(PROXY_EXISTS),1)
	DOCKER_PROXY_FLAGS = --build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy}
else
	undefine DOCKER_PROXY_FLAGS
endif

init-wait: clean
	docker build ${DOCKER_PROXY_FLAGS} -t isecl/init-wait:$(VERSION) --label org.label-schema.build-date=$(BUILDDATE) -f init-wait/Dockerfile .
	skopeo copy docker-daemon:isecl/init-wait:$(VERSION) oci-archive:init-wait/init-wait-$(VERSION).tar

nats:   clean
	docker build ${DOCKER_PROXY_FLAGS} -t isecl/nats-init:$(VERSION) --label org.label-schema.build-date=$(BUILDDATE) -f nats/Dockerfile .
	skopeo copy docker-daemon:isecl/nats-init:$(VERSION) oci-archive:nats/nats-init-$(VERSION).tar

db-version-upgrade: clean
	docker build ${DOCKER_PROXY_FLAGS} -t isecl/db-version-upgrade:$(DB_VERSION_UPGRADE_11_14) --label org.label-schema.build-date=$(BUILDDATE) -f db-version-upgrade/Dockerfile .
	skopeo copy docker-daemon:isecl/db-version-upgrade:$(DB_VERSION_UPGRADE_11_14) oci-archive:db-version-upgrade/db-version-upgrade-$(DB_VERSION_UPGRADE_11_14).tar
all: nats init-wait db-version-upgrade

clean:
	rm -rf init-wait/*.tar
	rm -rf nats/*.tar

.PHONY: all clean nats init-wait db-version-upgrade

