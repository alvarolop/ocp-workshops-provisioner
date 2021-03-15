#!/bin/sh

set -e

##
# 0) PRECHECKS
## 

# Check if the user is logged in 
if ! oc whoami &> /dev/null; then
    echo -e "Check. You are not logged out. Please log in and run the script again."
    exit 1
else
    echo -e "Check. You are correctly logged in. Continue..."
    oc project default # To avoid issues with deleted projects
fi

##
# 1) USERS
## 

# Disabling project self-provisioning for plain users
# https://docs.openshift.com/container-platform/4.7/applications/projects/configuring-project-creation.html#disabling-project-self-provisioning_configuring-project-creation
oc patch clusterrolebinding.rbac self-provisioners -p '{"subjects": null}'
oc patch clusterrolebinding.rbac self-provisioners -p '{ "metadata": { "annotations": { "rbac.authorization.kubernetes.io/autoupdate": "false" } } }'

# Avoid needing -c command on htpasswd
rm -rf workshop-users.htpasswd
touch workshop-users.htpasswd

# Create projects for users
for userId in {01..10}; do

    echo -e "\nCreating user #$userId"

    # Create htpasswd file
    htpasswd -b -B workshop-users.htpasswd user$userId openshift

    # Create namespace and rolebinding
    oc process -f templates/users-template.yaml -p USERID=$userId | oc apply -f -
done

echo ""

oc create secret generic workshop-htpass-secret -n openshift-config --from-file=htpasswd=workshop-users.htpasswd


if ! oc patch OAuth cluster --type=json --patch='[{"op": "test", "path": "/spec/identityProviders/1/htpasswd/fileData/name", "value": "workshop-htpass-secret"}]' &> /dev/null; then
    echo -ne "\nOAuth provider was not set. Configuring..."
    oc patch OAuth cluster --type=json --patch='[{"op": "add", "path": "/spec/identityProviders/-", "value": {"name": "WORKSHOP LOGIN","challenge": true,"login": true,"mappingMethod": "claim","type": "HTPasswd","htpasswd": {"fileData": {"name": "workshop-htpass-secret"}}}}]'
    echo -e "[OK]\n"
else
    echo -e "\nOAuth provider was set. Skip."
fi


##
# 2) ETHERPAD
## 
echo -e "\Installing Etherpad in project 'etherpad'..."
git clone https://github.com/alvarolop/etherpad-for-openshift.git && cd etherpad-for-openshift && ./deploy.sh && cd -
rm -rf ./etherpad-for-openshift


##
# 3) DEPLOY WORKSHOP
# This script automatically installs Pipelines workshop, but can be customizable for anything
# https://github.com/openshift-labs/lab-tekton-pipelines/tree/4.6
## 
WORKSHOP_PROJECT_NAME=workshop

oc new-project $WORKSHOP_PROJECT_NAME --display-name "Pipelines Workshops"

git clone --recurse-submodules --branch 1.0 https://github.com/openshift-labs/lab-tekton-pipelines.git
cd lab-tekton-pipelines
.workshop/scripts/deploy-spawner.sh
cd ..
rm -rf lab-tekton-pipelines

HOMEROOM_ROUTE=$(oc get routes lab-tekton-pipelines -n $WORKSHOP_PROJECT_NAME --template='https://{{(index .items 0).spec.host }}')

echo -e "\Available URLs:"
# echo -e " * ETHERPAD URL: $HOMEROOM_ROUTE"
echo -e " * HOMEROOM URL: $HOMEROOM_ROUTE"

