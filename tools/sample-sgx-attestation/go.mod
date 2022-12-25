module github.com/intel-secl/sample-sgx-attestation/v5

require (
	github.com/gorilla/handlers v1.4.2
	github.com/gorilla/mux v1.7.4
	github.com/pkg/errors v0.9.1
	github.com/sirupsen/logrus v1.7.0
	github.com/spf13/viper v1.7.1
	intel/isecl/lib/common/v5 v5.1.0
)

replace intel/isecl/lib/common/v5 => github.com/intel-innersource/libraries.security.isecl.common/v5 v5.1/develop
