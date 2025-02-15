#!/bin/bash
#
# cicd_check_comments
#
# Script to test if there are Cirtical comments errors for an API/Version
#
# The Script uses the SwaggerHub Registry API.
#
# usage: cidi_check_comments <org> <api> <version>
#
# This script is not supported by SmartBear Software and is to be used as-is.
#
#   m. higgins    28/01/2021    inital coding (1.0.0)
#   m. higgins    31/05/2021    add User-Agent (1.0.1)
#
  
API_NAME="cicd_check_comments"
RELEASE="v1.0.1"

echo " "
echo "$API_NAME  ${RELEASE} - `date`"

###################################################################################################
# check that jq is installed

if ! jq --help &> /dev/null; then
   echo " "
   echo "The Linux utility jq must be installed to use this script"
   exit 1
fi

###################################################################################################
# read config file

CONFIG_FILE=$HOME/.swaggerhub-bash.cfg

if [ -f $CONFIG_FILE ]; then
   BUFFER=$(jq -r '.' $CONFIG_FILE)
   IS_SAAS=$(echo $BUFFER | jq -r '.is_saas')
   FQDN=$(echo $BUFFER | jq -r '.fqdn')
   REGISTRY_FQDN=$(echo $BUFFER | jq -r '.registry_fqdn')
   MANAGEMENT_FQDN=$(echo $BUFFER | jq -r '.management_fqdn')
   ADMIN_FQDN=$(echo $BUFFER | jq -r '.admin_fqdn')
   API_KEY=$(echo $BUFFER | jq -r '.api_key')
   ADMIN_USERNAME=$(echo $BUFFER | jq -r '.admin_username')
   DEFAULT_ORG=$(echo $BUFFER | jq -r '.default_org')
else
   echo " "
   echo "No Config file found, please run make_swaggerhub_config.sh"
   exit 1
fi

###################################################################################################
# test to see if the SwaggerHub CLI is installed

if swaggerhub --help &> /dev/null; then
   CLI="true"
else
   CLI="false"
fi

######################################################################################################
# process the command line arguements

if [ $# -ne 3 ]
then
   echo " "
   echo "Incorrect command line arguements."
   echo " "
   echo "usage: $API_NAME <org> <api> <version>"
   echo " "
   exit 1
fi

ORG=$1
API=$2
VER=$3

###################################################################################################
# check Organization exists AND get the total count of APIs in the Organization

TOTALCOUNT=$(curl -sk -X GET "$REGISTRY_FQDN/apis/$ORG"     \
                      -H "accept: application/json"         \
                      -H "Authorization: Bearer $API_KEY"   \
                      -H "User-Agent: $API_NAME"            \
             | jq '.totalCount')

if [ ${TOTALCOUNT} == null ]; then
   echo " "
   echo "Invalid <organization> or <api-key> entered"
   exit 1
fi

###################################################################################################
# check the API/Verion exists

if [ $CLI == "true" ]; then

   STRING1=$(swaggerhub api:get $ORG/$API/$VER --json)

else

   STRING1=$(curl -sk -X GET "$REGISTRY_FQDN/apis/$ORG/$API/$VER/swagger.json" \
                      -H "accept: application/json"                            \
                      -H "User-Agent: $API_NAME"                               \
                      -H "Authorization: Bearer $API_KEY")
fi

TEST=$(echo $STRING1 | jq '.info')

if [ ${#TEST} -lt 10 ]; then
   echo " "
   echo "API/Version not found."
   exit 1
fi

######################################################################################################
# begin


STRING2=$(curl -sk -X GET "$REGISTRY_FQDN/apis/$ORG/$API/$VER/comments"  \
                   -H "accept: application/json"                         \
                   -H "User-Agent: $API_NAME"                            \
                   -H "Authorization: Bearer $API_KEY")
   
TEST=$(echo $STRING2 | jq -r '.[].status' | grep OPEN | wc -l)

######################################################################################################
# report

if [ $TEST -gt 0 ];then
   echo " "
   echo "ERROR: $ORG/$API/$VER has $TEST Open Comments - Exit 1"
   echo " "
   exit 1
else
   echo " "
   echo "INFO: $ORG/$API/$VER has NO Open comments - Exit 0"
   echo " "
   exit 0
fi

