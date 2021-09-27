GITTAG := $(shell git describe --tags --abbrev=0 2> /dev/null)
GITCOMMIT := $(shell git describe --always)
GITCOMMITDATE := $(shell git log -1 --date=short --pretty=format:%cd)
VERSION := $(or ${GITTAG}, v4.0)
BUILDDATE := $(shell TZ=UTC date +%Y-%m-%dT%H:%M:%S%z)

.PHONY: installer test all clean

ta-sim: clean
	env GOOS=linux GOSUMDB=off GOPROXY=direct go mod tidy && GOOS=linux GOSUMDB=off GOPROXY=direct go build -ldflags "-X main.BuildDate=$(BUILDDATE) -X main.Version=$(VERSION) -X main.GitHash=$(GITCOMMIT)"

ta-sim-installer: ta-sim
	mkdir -p installer
	mkdir -p installer/configuration
	mkdir -p installer/repository
	mkdir -p deployments
	mkdir -p deployments/installer

	cp ta-sim installer/
	cp setup.sh installer/
	chmod 755 installer/setup.sh
	cp tagent-sim.sh installer/
	chmod 755 installer/tagent-sim.sh
	cp test/configuration/config.yml installer/configuration
	cp test/configuration/opensslSAN.conf installer/configuration
	cp test/repository/host_info.json installer/repository
	cp test/repository/quote.xml installer/repository
	makeself installer deployments/installer/ta-sim-$(VERSION).bin "Go Trust Agent Simulator $(VERSION)" ./setup.sh
	cp go-ta-sim.env deployments/installer/
	rm -rf installer

installer: ta-sim-installer

test:
	env GOOS=linux GOSUMDB=off GOPROXY=direct go mod tidy
	go test ./... -coverprofile cover.out
	go tool cover -func cover.out
	go tool cover -html=cover.out -o cover.html

all: clean installer test

clean:
	rm -f cover.*
	rm -f ta-sim
	rm -rf installer/
	rm -rf deployments/
