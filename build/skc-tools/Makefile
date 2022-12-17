# Building Container

bin: app

all: k8s

app: 
	cd utils/build/skc-tools/sample_apps/build_scripts/ && ./sample_apps_build.sh
	mkdir -p binaries
	cp utils/build/skc-tools/sample_apps/build_scripts/sample_apps.* binaries/
	cp utils/build/skc-tools/sample_apps/sampleapps_untar.sh binaries/

k8s: k8s_common init-containers
	cp -r intel-secl/deployments/k8s/* k8s/manifests/
	cp -r utils/build/skc-tools/skc_k8s/create-skc-dirs-nfs.sh k8s/
	cp -r sgx-caching-service/out/k8s k8s/manifests/scs
	cp -r sgx-verification-service/out/k8s k8s/manifests/sqvs
	cp -r sgx-hvs/out/k8s k8s/manifests/shvs
	cp -r utils/build/skc-tools/skc_k8s/trusted_rootca_files k8s/manifests/sqvs/
	cp -r utils/build/skc-tools/sgx_agent/agent_untar.sh k8s/platform-dependencies/
	cp -r utils/build/skc-tools/sgx_agent/deploy_scripts/deployment_prerequisites.sh k8s/platform-dependencies/
	cp -r intel-secl/deployments/container-archive/oci/*.tar k8s/container-images/
	cp sgx-caching-service/out/*.tar k8s/container-images/
	cp sgx-verification-service/out/*.tar k8s/container-images/
	cp sgx-hvs/out/*.tar k8s/container-images/
	cp sgx_agent/out/*.tar k8s/container-images/
	cp -r utils/build/skc-tools/sgx_agent/build_scripts/sgx_agent.* k8s/platform-dependencies/
	cp -r utils/build/skc-tools/sgx_agent/deploy_scripts/agent_container_prereq.sh k8s/platform-dependencies/

k8s-aio-stacks: k8s_common_stacks

k8s-stacks: k8s_common_stacks

init-containers:
	cd  utils/tools/containers/ && make init-wait

clean:
	cd intel-secl && make clean
	cd sgx-caching-service && make clean
	cd sgx-verification-service && make clean
	cd sgx_agent && make clean
	cd sgx-hvs && make clean
	rm -rf binaries/
	rm -rf k8s/
	
skc_library:
	cd utils/build/skc-tools/skc_library/build_scripts/ && ./skc_library_build.sh

skc_k8s:
	cd sgx-caching-service && make k8s
	cd sgx-hvs && make k8s
	cd sgx-verification-service && make k8s

intel_secl_k8s:
	cd intel-secl && make authservice-k8s && make cms-k8s && make ihub-k8s && make kbs-k8s && make isecl-k8s-extensions-installer

sgx_agent_k8s:
	cd utils/build/skc-tools/sgx_agent/build_scripts/ && ./build_sgx_agent_docker.sh

skc_library_k8s:
	cd utils/build/skc-tools/skc_library/build_scripts/ && ./build_skc_docker.sh

sgx_agent_k8s_stacks:
	cd utils/build/skc-tools/stacks/sgx_agent/build_scripts/ && ./build_sgx_agent_docker.sh

skc_library_k8s_stacks:
	cd utils/build/skc-tools/stacks/skc_library/build_scripts/ && ./build_skc_docker.sh

k8s_common_services:
	mkdir -p k8s/container-images
	mkdir -p k8s/manifests
	mkdir -p k8s/platform-dependencies
	mkdir -p k8s/sample_apps
	cp -pf utils/build/skc-tools/config k8s/manifests/
	cp utils/build/skc-tools/sample_apps/sampleapps_untar.sh k8s/sample_apps/
	cp -r utils/build/skc-tools/skc_k8s/pre-requisites.sh k8s/manifests/
	cp  utils/build/skc-tools/skc_library/deploy_scripts/create_roles.conf utils/build/skc-tools/skc_k8s/skc_library/resources/
	cp  utils/build/skc-tools/skc_library/deploy_scripts/skc_library_create_roles.sh utils/build/skc-tools/skc_k8s/skc_library/resources/
	cp  utils/build/skc-tools/skc_library/deploy_scripts/skc_library.conf utils/build/skc-tools/skc_k8s/skc_library/resources/
	cp -r utils/build/skc-tools/skc_k8s/skc_library k8s/manifests/skc_library
	cp -r utils/build/skc-tools/skc_k8s/skc-bootstrap.sh k8s/manifests/skc-bootstrap.sh
	cp utils/build/skc-tools/skc_k8s/isecl-skc-k8s.env k8s/manifests/isecl-skc-k8s.env
	cp -r utils/build/skc-tools/kbs_script k8s/manifests/kbs_script/
	cp skc_library/out/*.tar k8s/container-images/

k8s_common: clean intel_secl_k8s skc_k8s sgx_agent_k8s skc_library_k8s app k8s_common_services
	cp utils/build/skc-tools/sample_apps/build_scripts/sample_apps.* k8s/sample_apps/

k8s_common_stacks: clean intel_secl_k8s skc_k8s sgx_agent_k8s_stacks skc_library_k8s_stacks app_stacks k8s_common_services
	cp utils/build/skc-tools/stacks/sample_apps/build_scripts/sample_apps.* k8s/sample_apps/
	cp -r utils/build/skc-tools/stacks/sgx_agent/build_scripts/sgx_agent.* k8s/platform-dependencies/
	cp -r utils/build/skc-tools/stacks/sgx_agent/deploy_scripts/agent_container_prereq.sh k8s/platform-dependencies/

app_stacks: 
	cd utils/build/skc-tools/stacks/sample_apps/build_scripts/ && ./sample_apps_build.sh
	mkdir -p binaries
	cp utils/build/skc-tools/stacks/sample_apps/build_scripts/sample_apps.* binaries/
	cp utils/build/skc-tools/sample_apps/sampleapps_untar.sh binaries/

skc_library_k8s_deploy:
	mkdir -p k8s/manifests/
	mkdir -p k8s/container-images/
	cp -pf utils/build/skc-tools/config k8s/manifests/
	cp -r utils/build/skc-tools/kbs_script k8s/manifests/
	chmod a+x k8s/manifests/kbs_script/run.sh
	cp -r utils/build/skc-tools/skc_k8s/skc_library k8s/manifests/skc_library
	cp -r utils/build/skc-tools/skc_k8s/skc-bootstrap.sh k8s/manifests/skc-bootstrap.sh
	cp utils/build/skc-tools/skc_k8s/isecl-skc-k8s.env k8s/manifests/isecl-skc-k8s.env

sgx_common: init-containers
	cd intel-secl && make authservice-k8s && make cms-k8s
	cd sgx-caching-service && make k8s
	cd sgx-verification-service && make k8s
	cd utils/build/skc-tools/sgx_agent/build_scripts/ && ./build_sgx_agent_docker.sh

sgx_infrastructure: clean skc_library_k8s sgx_common
	cd intel-secl && make kbs-k8s
	mkdir -p k8s/container-images
	mkdir -p k8s/manifests
	mkdir -p k8s/platform-dependencies
	cp -pf utils/build/skc-tools/config k8s/manifests/
	cp -r utils/build/skc-tools/skc_k8s/pre-requisites.sh k8s/manifests/
	cp  utils/build/skc-tools/skc_library/deploy_scripts/create_roles.conf utils/build/skc-tools/skc_k8s/skc_library/resources/
	cp  utils/build/skc-tools/skc_library/deploy_scripts/skc_library_create_roles.sh utils/build/skc-tools/skc_k8s/skc_library/resources/
	cp  utils/build/skc-tools/skc_library/deploy_scripts/skc_library.conf utils/build/skc-tools/skc_k8s/skc_library/resources/
	cp -r utils/build/skc-tools/skc_k8s/skc_library k8s/manifests/skc_library
	cp -r utils/build/skc-tools/skc_k8s/skc-bootstrap.sh k8s/manifests/skc-bootstrap.sh
	cp utils/build/skc-tools/skc_k8s/isecl-skc-k8s.env k8s/manifests/isecl-skc-k8s.env
	cp -r utils/build/skc-tools/kbs_script k8s/manifests/kbs_script/
	cp skc_library/out/*.tar k8s/container-images/
	cp -r intel-secl/deployments/k8s/* k8s/manifests/
	cp -r utils/build/skc-tools/skc_k8s/create-skc-dirs-nfs.sh k8s/
	cp -r sgx-caching-service/out/k8s k8s/manifests/scs
	cp -r sgx-verification-service/out/k8s k8s/manifests/sqvs
	cp -r utils/build/skc-tools/skc_k8s/trusted_rootca_files k8s/manifests/sqvs/
	cp -r utils/build/skc-tools/sgx_agent/agent_untar.sh k8s/platform-dependencies/
	cp -r utils/build/skc-tools/sgx_agent/deploy_scripts/deployment_prerequisites.sh k8s/platform-dependencies/
	cp -r intel-secl/deployments/container-archive/oci/*.tar k8s/container-images/
	cp sgx-caching-service/out/*.tar k8s/container-images/
	cp sgx-verification-service/out/*.tar k8s/container-images/
	cp sgx_agent/out/*.tar k8s/container-images/
	cp -r utils/build/skc-tools/sgx_agent/build_scripts/sgx_agent.* k8s/platform-dependencies/
	cp -r utils/build/skc-tools/sgx_agent/deploy_scripts/agent_container_prereq.sh k8s/platform-dependencies/

sgx_orchestration: clean sgx_common
	cd sgx-hvs && make k8s
	cd intel-secl && make ihub-k8s && make isecl-k8s-extensions-installer
	mkdir -p k8s/container-images
	mkdir -p k8s/manifests
	mkdir -p k8s/platform-dependencies
	cp -r intel-secl/deployments/k8s/* k8s/manifests/
	cp -r utils/build/skc-tools/skc_k8s/create-skc-dirs-nfs.sh k8s/
	cp -r sgx-caching-service/out/k8s k8s/manifests/scs
	cp -r sgx-verification-service/out/k8s k8s/manifests/sqvs
	cp -r sgx-hvs/out/k8s k8s/manifests/shvs
	cp -r utils/build/skc-tools/skc_k8s/trusted_rootca_files k8s/manifests/sqvs/
	cp -r utils/build/skc-tools/sgx_agent/agent_untar.sh k8s/platform-dependencies/
	cp -r utils/build/skc-tools/sgx_agent/deploy_scripts/deployment_prerequisites.sh k8s/platform-dependencies/
	cp -r intel-secl/deployments/container-archive/oci/*.tar k8s/container-images/
	cp sgx-caching-service/out/*.tar k8s/container-images/
	cp sgx-verification-service/out/*.tar k8s/container-images/
	cp sgx-hvs/out/*.tar k8s/container-images/
	cp sgx_agent/out/*.tar k8s/container-images/
	cp -r utils/build/skc-tools/sgx_agent/build_scripts/sgx_agent.* k8s/platform-dependencies/
	cp -r utils/build/skc-tools/sgx_agent/deploy_scripts/agent_container_prereq.sh k8s/platform-dependencies/

.PHONY: all clean app skc_library app_stacks k8s k8s_common_stacks k8s_common intel_secl_k8s skc_k8s sgx_agent_k8s skc_library_k8s sgx_common sgx_infrastructure sgx_orchestration
