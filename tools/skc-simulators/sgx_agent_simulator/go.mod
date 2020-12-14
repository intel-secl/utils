module intel/isecl/sgx_agent/v3

go 1.14

require (
	github.com/google/uuid v1.1.2
	github.com/gorilla/handlers v1.4.0
	github.com/gorilla/mux v1.7.3
	github.com/klauspost/cpuid v1.2.1
	github.com/pkg/errors v0.9.1
	github.com/sirupsen/logrus v1.4.0
	github.com/stretchr/testify v1.3.0
	gopkg.in/yaml.v2 v2.2.2
	gopkg.in/yaml.v3 v3.0.0-20200615113413-eeeca48fe776
	intel/isecl/lib/clients/v3 v3.3.0
	intel/isecl/lib/common/v3 v3.3.0
)

replace (
	intel/isecl/lib/common/v3 => gitlab.devtools.intel.com/sst/isecl/lib/common.git/v3 v3.2.1-0.20201210093129-f69e25a42d47
	intel/isecl/lib/clients/v3 => gitlab.devtools.intel.com/sst/isecl/lib/clients.git/v3 v3.2.1-0.20201210093740-034189f165d8
)
