module intel/isecl/sgx_agent/v5

require (
	github.com/Waterdrips/jwt-go v3.2.1-0.20200915121943-f6506928b72e+incompatible
	github.com/google/uuid v1.2.0
	github.com/klauspost/cpuid v1.2.1
	github.com/pkg/errors v0.9.1
	github.com/sirupsen/logrus v1.7.0
	github.com/stretchr/testify v1.6.1
	gopkg.in/yaml.v2 v2.4.0
	intel/isecl/lib/clients/v5 v5.0.0
	intel/isecl/lib/common/v5 v5.0.0
)

replace (
	intel/isecl/lib/common/v5 => gitlab.devtools.intel.com/sst/isecl/lib/common.git/v5 v5.0/develop
	intel/isecl/lib/clients/v5 => gitlab.devtools.intel.com/sst/isecl/lib/clients.git/v5 v5.0/develop
)
