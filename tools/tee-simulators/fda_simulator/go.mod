module intel/isecl/fda-sim/v5

require (
	github.com/google/uuid v1.2.0
	github.com/intel-secl/intel-secl-tee/v5 v5.0.0
	github.com/intel-secl/intel-secl/v5 v5.0.0
	github.com/pkg/errors v0.9.1
	github.com/sirupsen/logrus v1.8.1
	github.com/spf13/viper v1.7.1
	gopkg.in/yaml.v3 v3.0.0-20210107192922-496545a6307b
)

replace (
	github.com/intel-secl/intel-secl-tee/v5 => gitlab.devtools.intel.com/sst/isecl/intel-secl-tee.git/v5 v4.0/develop
	github.com/intel-secl/intel-secl/v5 => gitlab.devtools.intel.com/sst/isecl/intel-secl.git/v5 v5.0/develop
)
