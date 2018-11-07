# OpenShift - Lab Environment

## This project contains a collection of tools and resources required to 
## implement OpenShift Container Platform within the Santander environment.

## A script, which containerizes the install, has been created for 
## simplified deployments and reduced dependancy management, for example:
  1. Upgrading or rolling back entire OCP major versions will not require explicit management of openshift installation packages
  1. Custom playbooks may co-exist alongside fully supported installation playbooks, regardless of future changes to upstream code
  1. Deployment is as simple as ensuring the appropariate functions are called, and deployed with ./containerized

## For full product documentation around OpenShift, please see the following link:
## https://docs.openshift.com/container-platform/3.10/welcome/index.html
