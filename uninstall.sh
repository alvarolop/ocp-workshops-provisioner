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

# Create projects for users
for userId in {01..10}; do

    echo -e "\nDeleting user #$userId"

    # Create namespace and rolebinding
    oc process -f templates/users-template.yaml -p USERID=$userId | oc delete -f -
done

echo ""


# Use the following command to remove the OAuth provider if you want to uninstall
oc patch OAuth cluster --type=json --patch='[{"op": "test", "path": "/spec/identityProviders/1/htpasswd/fileData/name", "value": "workshop-htpass-secret"},{"op": "remove", "path": "/spec/identityProviders/1"}]'

oc delete secret workshop-htpass-secret -n openshift-config


##
# 2) ETHERPAD
## 
oc delete project etherpad


##
# 3) DEPLOY WORKSHOP
## 

