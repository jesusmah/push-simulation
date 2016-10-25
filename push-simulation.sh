##############################################################
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2011 All rights reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with
# IBM Corp.
###############################################################

#!/bin/sh

# Script to simulate a cf push for containers.

# Read properties
. config.cfg

# clean working directory
printf "Cleaning working directory..."
if [ -d "$WORK_DIR" ]; then
  rm -rf $WORK_DIR >>log_file.log 2>&1
fi
if [ -d "artifacts" ]; then
  rm -rf artifacts >>log_file.log 2>&1
fi
printf "DONE\n"

# Create artifact location
mkdir artifacts

# Copy Dockerfile into artifacts folder for container creation
cp Dockerfile artifacts

# Clone repo
printf "Cloning working directory..."
git clone $GIT_REPO >>log_file.log 2>&1
if [ $? -ne 0 ]; then
  printf "\n"
  printf "[ERROR]: An error has ocurred pulling the code from its GitHub repository\n"
  exit 1
fi
printf "DONE\n"

# build repo
printf "Building app..."
cd $WORK_DIR
mvn clean package >>log_file.log 2>&1
if [ $? -ne 0 ]; then
  printf "\n"
  printf "[ERROR]: An error has ocurred building the app\n"
  exit 1
fi
cd ..
printf "DONE\n"

# Grab artifacts needed during container creation
#for artifact in $ARTIFACT_LIST
#do
  #cp $artifact artifacts
#done

printf "Copying build output..."
cp $WORK_DIR/$ARTIFACT_LIST artifacts
BUILD_OUTPUT=`basename $ARTIFACT_LIST`
mv artifacts/$BUILD_OUTPUT artifacts/app.jar
printf "DONE\n"

# Bluemix login
. $BMX_CREDENTIALS_FILE
. $BMX_PASS_FILE
printf "Logging into Bluemix..."
cf login -a $BMX_API -o $BMX_ORG -s $BMX_SPACE -u $BMX_USER -p $BMX_PASS >>log_file.log 2>&1
if [ $? -ne 0 ]; then
  printf "\n"
  printf "[ERROR]: An error has ocurred logging into Bluemix\n"
  exit 1
fi
printf "DONE\n"

# Container service login
printf "Initializing Bluemix containers..."
cf ic init >>log_file.log 2>&1
if [ $? -ne 0 ]; then
  printf "\n"
  printf "[ERROR]: An error has ocurred initializing Bluemix containers\n"
  exit 1
fi
printf "DONE\n"

# Build container in Bluemix
cd artifacts
printf "Building the container in Bluemix..."
cf ic build -t $BMX_REGISTRY/$BMX_NAMESPACE/$CONTAINER_IMAGE:latest . >>log_file.log 2>&1
if [ $? -ne 0 ]; then
  printf "\n"
  printf "[ERROR]: An error has ocurred building the container\n"
  exit 1
fi
printf "DONE\n"

# Spin up conatiner group
printf "Spinning up the container in a container group in Bluemix..."
CONTAINER_GROUP_ID=`cf ic group create --name $CONTAINER_GROUP_NAME -p 8180 -m 256 --min 1 --max 2 --desired 1 $BMX_REGISTRY/$BMX_NAMESPACE/$APP_NAME:latest | grep id | sed 's/^.*id: //g' | sed 's/).*$//g'`
if [ $? -ne 0 ]; then
  printf "\n"
  printf "[ERROR]: An error has ocurred spinning up the container\n"
  exit 1
fi
printf "DONE\n"

# Wait for the container group creation to finish
ITERATION=0
while [[ `cf ic group list | grep $CONTAINER_GROUP_ID | grep COMPLETE | wc -l` -ne 1 && $ITERATION -lt 10 ]]
do
  ITERATION=$((ITERATION + 1))
  sleep 10
done

if [ $ITERATION -eq 10 ]
then
  echo "An error has occured while creating the container group"
  exit 1
fi

exit 0

# Create public route

# Map public route to the container group
