module intel/isecl/tools/bkc/v5

require (
	github.com/google/uuid v1.2.0
	github.com/intel-secl/intel-secl/v5 v5.1.0
	github.com/pkg/errors v0.9.1
	github.com/sirupsen/logrus v1.8.1
)

replace (
	github.com/vmware/govmomi => github.com/arijit8972/govmomi fix-tpm-attestation-output
)
