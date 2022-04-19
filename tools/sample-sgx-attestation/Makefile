GITTAG := $(shell git describe --tags --abbrev=0 2> /dev/null)
GITCOMMIT := $(shell git describe --always)
GITCOMMITDATE := $(shell git log -1 --date=short --pretty=format:%cd)
VERSION := $(or ${GITTAG}, v4.2.0)
BUILDDATE := $(shell TZ=UTC date +%Y-%m-%dT%H:%M:%S%z)

default: all

certs:
	mkdir -p out/
	cp *.pem out/
	chmod 400 out/*.pem

attestingapp: certs
	cd attestingApp && env GOOS=linux GOSUMDB=off GOPROXY=direct go mod tidy && GOOS=linux GOSUMDB=off GOPROXY=direct go build -ldflags "-X github.com/intel-secl/sample-sgx-attestation/v4/attestingApp/version.BuildDate=$(BUILDDATE) -X github.com/intel-secl/sample-sgx-attestation/v4/attestingApp/version.Version=$(VERSION) -X github.com/intel-secl/sample-sgx-attestation/v4/attestingApp/version.GitHash=$(GITCOMMIT)" -o ../out/sgx-attesting-app
	cp sgx-quote-policy.txt out/
	cp config.yml.tmpl out/config.yml

attestedapplib:
	cd attestedApp/libenclave/ && $(MAKE) all

attestedapp: attestedapplib certs
	cd attestedApp && env GOOS=linux GOSUMDB=off GOPROXY=direct go mod tidy && GOOS=linux GOSUMDB=off GOPROXY=direct go build -ldflags "-X github.com/intel-secl/sample-sgx-attestation/v4/attestedApp/version.BuildDate=$(BUILDDATE) -X github.com/intel-secl/sample-sgx-attestation/v4/attestedApp/version.Version=$(VERSION) -X github.com/intel-secl/sample-sgx-attestation/v4/attestedApp/version.GitHash=$(GITCOMMIT)" -o ../out/sgx-attested-app
	cp attestedApp/libenclave/untrusted.so out/untrusted.so
	cp attestedApp/libenclave/enclave.signed.so out/enclave.signed.so

swagger:
	mkdir -p out/swagger
	env GOOS=linux GOSUMDB=off GOPROXY=direct swagger generate spec -w ./swagger/$* -o ./out/swagger/openapi.yml
	swagger validate ./out/swagger/openapi.yml

.PHONY: all clean swagger

clean:
	make -C attestedApp/libenclave/ clean
	rm -rf go.sum out/ cover.*

all: clean  attestingapp attestedapplib attestedapp
