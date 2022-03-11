GITTAG := $(shell git describe --tags --abbrev=0 2> /dev/null)
GITCOMMIT := $(shell git describe --always)
BUILDDATE := $(shell TZ=UTC date +%Y-%m-%dT%H:%M:%S%z)
VERSION := "v5.0.0"

fda-sim:
	env GOOS=linux GOSUMDB=off GOPROXY=direct go mod tidy && env GOOS=linux GOSUMDB=off GOPROXY=direct go build -o out/fda-sim

installer: fda-sim
	mkdir -p out/installer
	cp dist/linux/install.sh out/installer/install.sh && chmod +x out/installer/install.sh
	cp out/fda-sim out/installer/fda-sim
	makeself out/installer out/fda-sim-$(VERSION).bin "FDA Simulator $(VERSION)" ./install.sh
	rm -rf installer

all: clean installer

clean:
	rm -rf out/*

.PHONY: installer all clean
