module intel/isecl/tools/bkc/v3

require (
	github.com/google/uuid v1.1.1
	github.com/intel-secl/intel-secl/v3 v3.6.0
	github.com/klauspost/cpuid v1.3.1
	github.com/pkg/errors v0.9.1
	intel/isecl/lib/common/v3 v3.6.0
	intel/isecl/lib/platform-info/v3 v3.6.0
	intel/isecl/lib/tpmprovider/v3 v3.6.0
	github.com/vmware/govmomi v0.22.2
)

replace (
	intel/isecl/lib/common/v3 => github.com/intel-secl/common/v3 v3.6.0
	intel/isecl/lib/tpmprovider/v3 => gitlab.devtools.intel.com/sst/isecl/lib/tpm-provider/v3 v3.6.0
	intel/isecl/lib/platform-info/v3 => gitlab.devtools.intel.com/sst/isecl/lib/platform-info/v3 v3.6.0
	github.com/vmware/govmomi => github.com/arijit8972/govmomi fix-tpm-attestation-output
)
