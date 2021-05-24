module github.com/intel-secl/sample-sgx-attestation/v3

require (
	github.com/pkg/errors v0.9.1
	github.com/sirupsen/logrus v1.5.0
	github.com/spf13/viper v1.7.0
	gopkg.in/yaml.v2 v2.3.0
	intel/isecl/lib/common/v3 v3.6.0
)

replace intel/isecl/lib/common/v3 => github.com/intel-secl/common/v3 v3.6.0
