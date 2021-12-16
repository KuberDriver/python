#!/bin/bash

# Copyright 2017 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -x

function clean_exit(){
    local error_code="$?"
    local spawned=$(jobs -p)
    if [ -n "$spawned" ]; then
        sudo kill $(jobs -p)
    fi
    return $error_code
}

trap "clean_exit" EXIT

MINIKUBE_OK="false"

# echo "Waiting for minikube to start..."
# this for loop waits until kubectl can access the api server that Minikube has created
for i in {1..20}; do # timeout for 3 minutes
 kubectl get po &> /dev/null
   if [ $? -ne 1 ]; then
      MINIKUBE_OK="true"
      break
  fi
  sleep 2
done

# Shut down CI if minikube did not start and show logs
if [ $MINIKUBE_OK == "false" ]; then
  sudo minikube logs
  echo "minikube did not start (line: ${LINENO})"
  exit 1
fi

echo "Dump Kubernetes Objects..."
kubectl get componentstatuses
kubectl get configmaps
kubectl get daemonsets
kubectl get deployments
kubectl get events
kubectl get endpoints
kubectl get horizontalpodautoscalers
kubectl get ingress
kubectl get jobs
kubectl get limitranges
kubectl get nodes
kubectl get namespaces
kubectl get pods
kubectl get persistentvolumes
kubectl get persistentvolumeclaims
kubectl get quota
kubectl get resourcequotas
kubectl get replicasets
kubectl get replicationcontrollers
kubectl get secrets
kubectl get serviceaccounts
kubectl get services


echo "Running tests..."
set -x -e
# Yield execution to venv command
$*