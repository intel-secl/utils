GITTAG := $(shell git describe --tags --abbrev=0 2> /dev/null)
GITCOMMIT := $(shell git describe --always)
VERSION := $(or ${GITTAG}, v0.0.0)
BUILDDATE := $(shell TZ=UTC date +%Y-%m-%dT%H:%M:%S%z)
PROXY_EXISTS := $(shell if [[ "${https_proxy}" || "${http_proxy}" ]]; then echo 1; else echo 0; fi)
DOCKER_PROXY_FLAGS := ""
ifeq ($(PROXY_EXISTS),1)
	DOCKER_PROXY_FLAGS = --build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy}
endif

.PHONY: sgx_agent installer docker all clean

all: clean installer

installer: sgx_agent
	mkdir -p out/installer
	cp dist/linux/sgx_agent.service out/installer/sgx_agent.service
	cp dist/linux/install.sh out/installer/install.sh && chmod +x out/installer/install.sh
	cp out/sgx_agent out/installer/sgx_agent
	makeself out/installer out/sgx_agent-$(VERSION).bin "SGX Agent $(VERSION)" ./install.sh

sgx_agent:
	env GOOS=linux GOSUMDB=off GOPROXY=direct go build -ldflags "-X intel/isecl/sgx_agent/v3/version.BuildDate=$(BUILDDATE) -X intel/isecl/sgx_agent/v3/version.Version=$(VERSION) -X intel/isecl/sgx_agent/v3/version.GitHash=$(GITCOMMIT)" -o out/sgx_agent

docker: sgx_agent
ifeq ($(PROXY_EXISTS),1)
	docker build ${DOCKER_PROXY_FLAGS} -f dist/image/Dockerfile -t isecl/sgx-agent:$(VERSION) .
else
	docker build -f dist/image/Dockerfile -t isecl/sgx-agent:$(VERSION) .
endif
	docker save isecl/sgx-agent:$(VERSION) > out/sgx-agent-$(VERSION)-$(GITCOMMIT).tar

sgx_agent-oci-archive: docker
	skopeo copy docker-daemon:isecl/sgx_agent:$(VERSION) oci-archive:out/sgx_agent-$(VERSION)-$(GITCOMMIT).tar

clean:
	rm -f cover.*
	rm -rf out/
