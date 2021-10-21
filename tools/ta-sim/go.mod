module github.com/intel-secl/ta-sim

require (
	github.com/google/uuid v1.3.0
	github.com/intel-secl/intel-secl/v5 v5.0.0
	github.com/nats-io/nats-server/v2 v2.3.0 // indirect
	github.com/nats-io/nats.go v1.11.0
	github.com/pkg/errors v0.9.1
	github.com/sirupsen/logrus v1.7.0
	github.com/spf13/viper v1.7.1
)

replace github.com/intel-secl/intel-secl/v5 => gitlab.devtools.intel.com/sst/isecl/intel-secl.git/v5 v5.0/develop