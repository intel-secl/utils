module github.com/intel-secl/sample-sgx-attestation/v4

require (
	github.com/gorilla/handlers v1.4.2
	github.com/gorilla/mux v1.7.3
	github.com/pkg/errors v0.9.1
	github.com/sirupsen/logrus v1.5.0
	github.com/spf13/viper v1.7.0
	gopkg.in/yaml.v2 v2.3.0
	intel/isecl/lib/common/v4 v4.0.3
)

replace intel/isecl/lib/common/v4 => github.com/intel-secl/common/v4 v4.0.3
