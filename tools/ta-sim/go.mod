module github.com/intel-secl/ta-sim

require (
	github.com/google/uuid v1.3.0
	github.com/intel-secl/intel-secl/v5 v5.1.0
	github.com/nats-io/nats.go v1.15.0
	github.com/pkg/errors v0.9.1
	github.com/sirupsen/logrus v1.7.0
	github.com/spf13/viper v1.7.1
)

replace github.com/intel-secl/intel-secl/v5 => github.com/intel-innersource/applications.security.isecl.intel-secl/v5 v5.1/develop
