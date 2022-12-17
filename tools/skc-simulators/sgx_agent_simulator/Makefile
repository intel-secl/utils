GITTAG := $(shell git describe --tags --abbrev=0 2> /dev/null)
GITCOMMIT := $(shell git describe --always)
VERSION := "v4.2.0"
BUILDDATE := $(shell TZ=UTC date +%Y-%m-%dT%H:%M:%S%z)
PROXY_EXISTS := $(shell if [[ "${https_proxy}" || "${http_proxy}" ]]; then echo 1; else echo 0; fi)
DOCKER_PROXY_FLAGS := ""
MONOREPO_GITURL := "https://github.com/intel-secl/intel-secl"
MONOREPO_GITBRANCH := "v4.2.0-Beta"

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

	git clone --depth 1 -b $(MONOREPO_GITBRANCH) $(MONOREPO_GITURL) tmp_monorepo
	cp -a tmp_monorepo/pkg/lib/common/upgrades/* out/installer/
	rm -rf tmp_monorepo
	cp -a upgrades/* out/installer
	mv out/installer/build/* out/installer
	chmod +x out/installer/*.sh

	makeself out/installer out/sgx_agent-$(VERSION).bin "SGX Agent $(VERSION)" ./install.sh

sgx_agent:
	env GOOS=linux GOSUMDB=off GOPROXY=direct go mod tidy && env GOOS=linux GOSUMDB=off GOPROXY=direct go build -ldflags "-X intel/isecl/sgx_agent/v4/version.BuildDate=$(BUILDDATE) -X intel/isecl/sgx_agent/v4/version.Version=$(VERSION) -X intel/isecl/sgx_agent/v4/version.GitHash=$(GITCOMMIT)" -o out/sgx_agent

docker: sgx_agent
ifeq ($(PROXY_EXISTS),1)
	docker build ${DOCKER_PROXY_FLAGS} -f dist/image/Dockerfile -t isecl/sgx-agent:$(VERSION) .
else
	docker build -f dist/image/Dockerfile -t isecl/sgx-agent:$(VERSION) .
endif
	docker save isecl/sgx-agent:$(VERSION) > out/sgx-agent-$(VERSION)-$(GITCOMMIT).tar

test:
	GOSUMDB=off GOPROXY=direct go  test ./... -coverprofile cover.out
	go tool cover -func cover.out
	go tool cover -html=cover.out -o cover.html

oci-archive: docker
	skopeo copy docker-daemon:isecl/sgx-agent:$(VERSION) oci-archive:out/sgx-agent-$(VERSION)-$(GITCOMMIT).tar

clean:
	rm -f cover.*
	rm -rf out/
