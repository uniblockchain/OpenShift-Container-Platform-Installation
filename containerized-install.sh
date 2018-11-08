#/bin/bash

# This script pulls the release version of OCP from the inventory file, pulls the appropriate 
# ose-anisble image from the Red Hat portal, and loads all needed files/folders/keys 
# into the deployment container. 
#
# Doing this eliminates dependency drift between OCP versions and eases
# the process of upgrades and maintainence
#
# What this means in more or less English is that all custom playbooks living in the 
# /playbooks directory will be mounted into an Ansible container alongside the Red Hat
# official installation code. Which container version this is will be dictated by your
# Inventory configuration, so the 'official' code is always current (or at least lock-step),
# while your custom work will always be available in parralel. Upgrades and downgrades do not
# reuqire dependancy management on the deployment server. 

setup() {
  echo "Performing Docker pre-req checks pre-deployment.."
  systemctl status docker > /dev/null 2>&1;
  if [ $? != '0' ]; then 
  	echo "Docker must be running prior to deployment, attempting to fix.."
	sleep 1s;
	systemctl start docker;
	if [ $? != 0 ]; then
		echo "Something is wrong with docker, inspect the journal for errors";
		exit 1;
	fi;
  fi;
  echo "Done!" 

  echo "Preparing the temporary environment...";
  TMPDIR=$(mktemp -d)
  echo "Done!"

  echo "Setting environment variables from inventory...";
  OCP_RELEASE="$(grep openshift_release inventory | cut -d "=" -f2 | awk '{print $1}')"
  ANSIBLE_USER="$(grep ansible_user inventory | cut -d "=" -f2)"
  echo "Done!"

  echo "Copying current invenvtory into temporary environment...";
  cp -r ./* "$TMPDIR";
  echo "Done!"
}
setup

_ansible() {
  docker run -ti -e ANSIBLE_SSH_PIPELINING=1 --net host --ipc host -u "$UID" -v "$TMPDIR":/tmp/ansible -v "$PWD"/playbooks:/tmp/playbooks \
-v "$HOME"/.ssh:/opt/app-root/src/.ssh:ro registry.access.redhat.com/openshift3/ose-ansible:"$OCP_RELEASE" -- ansible --ssh-extra-args=" -o ControlMaster=auto -o ControlPersist=60s PreferredAuthenitcations=publickey" \
-e ansible_ssh_user="$ANSIBLE_USER" -i /tmp/ansible/inventory "$@"
}

_ansible_playbook() {
  docker run -ti -e ANSIBLE_SSH_PIPELINING=1 --net host --ipc host -u "$UID" -v "$TMPDIR":/tmp/ansible -v "$PWD"/playbooks:/tmp/playbooks \
-v "$HOME"/.ssh:/opt/app-root/src/.ssh:ro registry.access.redhat.com/openshift3/ose-ansible:"$OCP_RELEASE" -- ansible-playbook --ssh-extra-args=" -o ControlMaster=auto -o ControlPersist=60s PreferredAuthenitcations=publickey" \
-e ansible_ssh_user="$ANSIBLE_USER" -i /tmp/ansible/inventory "$@"
}

# Define functionality 
create_user() {
  echo "Creating and configuring OCP deployment user"
  _ansible_playbook /tmp/playbooks/create-ocp-user.yml
}

ocpadmin_sudo() {
  echo "Running custom ocp-admin-sudoers playbook"
  _ansible_playbook /tmp/playbooks/ocpadmin_sudo.yml
}

environment() {
  echo "Running custom environment setup script"
  _ansible_playbook /tmp/playbooks/environment.yml
}

obliterateSat5() {
  echo "Running custom playbook to remove all traces of Satellite 5"
  _ansible_playbook /tmp/playbooks/obliterateSat5.yml
}

prep_hosts() {
  echo "Running custom host-preperation playbook (3.10);"
  _ansible_playbook /tmp/playbooks/prep_hosts.yml
}

set_docker_proxy() {
  echo "Running custom set_docker_proxy playbook"
  _ansible_playbook /tmp/playbooks/set_docker_proxy.yml
}

docker_storage_setup() {
  echo "Running custom docker storage setup, a requirement for inconsistent block IDs"
  _ansible_playbook /tmp/playbooks/docker_storage_setup.yml
}

pull_docker_images() {
  echo "Running custom pull_docker_images playbook"
  _ansible_playbook /tmp/playbooks/pull_docker_images.yml 
}

set_ip_forward() {
  echo "Running custom set_ip_forward playbook"
  _ansible_playbook /tmp/playbooks/set_ip_foward.yml
}

pre() {
  echo "Running OpenShift pre-req playbook";
  _ansible_playbook /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml
}

deploy() {
  echo "Deploying OpenShift Container Platform";
  _ansible_playbook /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml 
}

post_install() {
  echo "Running custom post-installation tasks"
  _ansible_playbook /tmp/playbooks/post_install_tasks.yml
}

create_sample_applications() {
  echo "Creating sample applications to showcase various OCP functionality"
  _ansible_playbook /tmp/playbooks/create_sample_apps.yml
}

uninstall() {
  echo "Uninstalling Openshift"
  _ansible_playbook /usr/share/ansible/openshift-ansible/playbooks/adhoc/uninstall_openshift.yml 
}

####################################
# Uncomment to include functionality
####################################

#######
# Setup 
#######

# create_user
# ocpadmin_sudo
# environment
# obliterateSat5
# prep_hosts
# set_docker_proxy
# docker_storage_setup
# pull_docker_images
# set_ip_forward

############
# Deployment
############

# pre
# deploy

###########
# Uninstall
###########

# uninstall
