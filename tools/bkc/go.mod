module intel/isecl/tools/bkc/v5

require (
	github.com/google/uuid v1.2.0
	github.com/intel-secl/intel-secl-tee/v5 v5.0.0
	github.com/intel-secl/intel-secl/v5 v5.0.0
	github.com/pkg/errors v0.9.1
	github.com/sirupsen/logrus v1.8.1
)

replace (
	github.com/intel-secl/intel-secl-tee/v5 => github.com/intel-innersource/applications.security.isecl.intel-secl-tee/v5 v5.0/develop
	github.com/intel-secl/intel-secl/v5 => github.com/intel-innersource/applications.security.isecl.intel-secl/v5 v5.0/develop
	github.com/vmware/govmomi => github.com/arijit8972/govmomi fix-tpm-attestation-output
)
