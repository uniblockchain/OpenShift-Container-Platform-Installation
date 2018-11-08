#!/bin/bash
## Note - Don't actually use this. While theoretically you can automate the process of moving artifacts from one platform to another,
# it would be a hell of lot cleaner, more reliable, and easier to use a CI/CD pipeline to re-deploy your workload to the new platform. 
# After all - you don't modify containers, you tear them down and spin them back up again


domain=$(hostname -d)

# ToDo - Warn user token is a reuqirement

# Set up temporary dir to hold project
export TMPDIR=`mktemp -d`

/usr/bin/oc --config=/etc/origin/master/admin.kubeconfig project default

# Set up Tokens and secrets
export OCP3_7="changeme"
export OCP3_9="`/usr/bin/oc --config=/etc/origin/master/admin.kubeconfig sa get-token {changeme, privileged service account}`"
export DOCKERPASS="changeme/docker login token"

# Authenticate to the 3.7 Cluster. Ideally this is a migration service account.
# A unique service account may be set up by issuing the following commands:
# /usr/bin/oc --config=/etc/origin/master/admin.kubeconfig create serviceaccount ${name} -n default 
# /usr/bin/oc --config=/etc/origin/master/admin.kubeconfig adm policy add-cluster-role-to-user cluster-admin system:serviceaccount:default:${name} -n default
# Note, a custom RBAC role with minimum privilege is something to consider
echo "Authenticating to OpenShift 3.7 using administrative service account"
/usr/bin/oc --config=/etc/origin/master/admin.kubeconfig login https://API.example.com --insecure-skip-tls-verify=true --token=${OCP3_7} >/dev/null 2>&1;


# Set up some test projects on 3.7 to migrate
# Will house test applications in a moment
for app in 1 2 3 4 5; do
	echo "Create new OpenShift test project for demo ${app}"; 
	/usr/bin/oc --config=/etc/origin/master/admin.kubeconfig new-project paas-536-migrate${app} >/dev/null 2>&1;
done

# Create the applications themelves in the projects created previously. 
# Each is set up to pull from the eternal registry
# and populated with a RedHat httpd container
for project in 1 2 3 4 5; do
	echo "Deploy test project ${project}"
	/usr/bin/oc --config=/etc/origin/master/admin.kubeconfig project ${project} >/dev/null 2>&1;
        /usr/bin/oc --config=/etc/origin/master/admin.kubeconfig secrets new-dockercfg -n paas-536-migrate${project} azure --docker-email='jnach@redhat.com' --docker-password=${DOCKERPASS} --docker-username='openshiftregistry2' --docker-server='openshiftregistry2.azurecr.io' >/dev/null 2>&1;
        /usr/bin/oc --config=/etc/origin/master/admin.kubeconfig secrets link -n paas-536-migrate${project} default azure --for=pull >/dev/null 2>&1;
        /usr/bin/oc --config=/etc/origin/master/admin.kubeconfig new-app -n paas-536-migrate${project} --docker-image=openshiftregistry2.azurecr.io/rhscl/httpd-24-rhel7 --name=paas-536-migrate${project} >/dev/null 2>&1;
        /usr/bin/oc --config=/etc/origin/master/admin.kubeconfig expose -n paas-536-migrate${project} svc/paas-536-migrate${project} >/dev/null 2>&1;
done

# Pause here to allow the Docker-pull operation
# to complete and the deployment to fully roll out
echo "Pause for 30 seconds to allow test projects to deploy"
sleep 30s


# Identify openshift default projects (infrastructure ) and
# assume namespaces that do not match are user applications that 
# must be migrated. For each project name, create a temporary
# directory under the same name to hold artifacts.
# And yes, this is a super redimentary filter.
for project in `/usr/bin/oc --config=/etc/origin/master/admin.kubeconfig export projects | grep '^    name:' | sed "s/^[ \t]*//" | cut -d ' ' -f2`; do
        if [ "$project" != "default" ] && [ "$project" != "grafana" ] && [ "$project" != "kube-public" ] && [ "$project" != "kube-system" ] && [ "$project" != "logging" ] && [ "$project" != "openshift" ] && [ "$project" != "openshift-infra" ] && [ "$project" != "openshift-metrics" ] && [ "$project" != "openshift-node" ] && [ "$project" != "management-infra" ] && [ "$project" != "openshift-metrics-backup" ]; then
        if [ ! -d ${TMPDIR}/${project} ]; then
                echo Creating directory for $project;
                mkdir -p ${TMPDIR}/$project;

        else
                echo "Directory ${TMPDIR}/${project} already exists"
        fi;
fi;
done

# Enumerate temporary directories that were just set up,
# and for each of them, interpolate the directory name
# into an export command to collect project artifacts, and
# re-direct this output into a .json file in temporary dir.
for dir in `ls ${TMPDIR}`; do
        if [ ! -e ${TMPDIR}/${dir}/${dir}.json ]; then
                echo Exporting project ${dir} into ${TMPDIR}/${dir};
                /usr/bin/oc --config=/etc/origin/master/admin.kubeconfig export all -n ${dir} -o json > ${TMPDIR}/${dir}/${dir}.json;
        else
                echo "/${dir}/${dir}.json already exists";
        fi;
done

# Identify the exposed routes for each exported application
# and store the value for later. 
#for dir in `ls ${TMPDIR}`; do
#	for route in `/usr/bin/oc --config=/etc/origin/master/admin.kubeconfig get route -n ${dir} | awk '{ print $1 }' | sed '/^NAME/d'`; do
#		 /usr/bin/oc --config=/etc/origin/master/admin.kubeconfig export route -n ${dir} ${route} > ${TMPDIR}/${dir}/${route}_backup.json;
#	 done
#done
 

# For all other artifacts that might be relavant to 
# the project, enumerate project names and export
# these additional OCP artifacts into a .json file
for dir in `ls ${TMPDIR}`; do
                for object in rolebindings serviceaccounts secrets imagestreamtags podpreset cms egressnetworkpolicies rolebindingrestrictions limitranges resourcequotas pvcs templates cronjobs statefulsets hpas deployments replicasets poddisruptionbudget endpoints; do
                        if [ ! -e ${TMPDIR}/${dir}/${object}.json ]; then
                                echo "Exporting ${object} for ${dir} into ${TMPDIR}/${dir}";
                                /usr/bin/oc --config=/etc/origin/master/admin.kubeconfig export -n ${dir} ${object} -o json > ${TMPDIR}/${dir}/${object}.json 2>/dev/null;
                        else
                                echo "Object ${TMPDIR}/${dir}/${object}.json already exists";
                fi;
        done
done

# Log out of OC
/usr/bin/oc --config=/etc/origin/master/admin.kubeconfig logout

# Log into the 3.9 Cluster
echo "Authenticating to OCP 3.9 Cluster using administrative service token"
/usr/bin/oc --config=/etc/origin/master/admin.kubeconfig login https://console.$domain  --insecure-skip-tls-verify=true --token=${OCP3_9} >/dev/null 2>&1;


# For each project, create a new namespace under 
# the project name in the new cluster, import project
# artifacts,  create a secret to allow pulling from the external 
# Docker Registry, and link the secret to the project. 
for dir in `ls ${TMPDIR}`; do
        if [ -e ${TMPDIR}/${dir}/${dir}.json ]; then
                echo "Importing project ${dir} into 3.9 Cluster";
		/usr/bin/oc --config=/etc/origin/master/admin.kubeconfig new-project ${dir} >/dev/null 2>&1;
		/usr/bin/oc --config=/etc/origin/master/admin.kubeconfig secrets new-dockercfg -n ${dir} azure --docker-email='jnach@redhat.com' --docker-password==pdbxZCJYBhHnHp/SZkfvrxf3kFJQdGV --docker-username='openshiftregistry2' --docker-server='openshiftregistry2.azurecr.io' 2>/dev/null;
		/usr/bin/oc --config=/etc/origin/master/admin.kubeconfig secrets link -n ${dir} default azure --for=pull 2>/dev/null;
                /usr/bin/oc --config=/etc/origin/master/admin.kubeconfig create -n ${dir} -f ${TMPDIR}/${dir}/${dir}.json 2>/dev/null;
        fi;
done

# Import the extra metadata that may be relevant
# to each project, rolebindings, secrets, etc..
for dir in `ls ${TMPDIR}`; do
                for object in rolebindings serviceaccounts secrets imagestreamtags podpreset cms egressnetworkpolicies rolebindingrestrictions limitranges resourcequotas pvcs templates cronjobs statefulsets hpas deployments replicasets poddisruptionbudget endpoints; do
                        if [ -e ${TMPDIR}/${dir}/${object}.json ]; then
                                echo "Importing ${object} for ${dir} into 3.9 Cluster";
                                /usr/bin/oc --config=/etc/origin/master/admin.kubeconfig create -n ${dir} -f ${TMPDIR}/${dir}/${object}.json 2>/dev/null;
                fi;
        done
done


# Update the deployment config to NOT use the imagestream
# By default, leaving in place results in an 'unresolved image' error
for dir in `ls ${TMPDIR}`; do
	echo "Updating deployment config in ${dir}"
	/usr/bin/oc --config=/etc/origin/master/admin.kubeconfig set triggers -n ${dir} dc/${dir} --remove --from-image="${dir}:latest";
done

# Re-deploy the project routes if they align with the current cluster subdomain
# May need to be adjusted if subdomain levels change
# Note, this example assumes route names match project names, 
# but this is not garunteed
for dir in `ls ${TMPDIR}`; do
	export OLDROUTE=`/usr/bin/oc --config=/etc/origin/master/admin.kubeconfig describe route -n ${dir} ${dir} | grep Host | cut -d ':' -f 2 | sed "s/^[ \t]*//" | cut -d '.' -f 2-5`;
	export NEWROUTE=`/usr/bin/oc --config=/etc/origin/master/admin.kubeconfig version | grep Server | cut -d ':' -f 2 | cut -d '.' -f 2-5`;
	if [ "${OLDROUTE}" != "${NEWROUTE}" ]; then # ToDo - if old != new AND old exists
		echo "Updating route in ${dir}"
		/usr/bin/oc --config=/etc/origin/master/admin.kubeconfig delete route -n ${dir} ${route} 2>/dev/null;
		/usr/bin/oc --config=/etc/origin/master/admin.kubeconfig expose service -n ${dir} ${route} 2>/dev/null;
	else
		echo "Route matches cluster subdomain in project ${dir}";
	fi;
done

