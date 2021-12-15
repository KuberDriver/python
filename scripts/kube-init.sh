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

# Switch off SE-Linux
setenforce 0

# Mount root to fix dns issues
# Define $HOME since somehow this is not defined
# HOME=/home/travis # Not required in GH Runner
sudo mount --make-rshared /

# Install conntrack (required by minikube/K8s 1.18+),
# and socat, which is required for port forwarding.
sudo apt-get update
sudo apt-get install -y conntrack socat

# Install docker if needed
path_to_executable=$(which docker)
if [ -x "$path_to_executable" ] ; then
    echo "Found Docker installation"
else
    curl -sSL https://get.docker.io | sudo bash
fi
docker --version

# Get the latest stable version of kubernetes, this is not always what minikube
# installs per default
# See:
# https://github.com/kubernetes/minikube/blob/master/pkg/minikube/constants/constants.go
K8S_VERSION=$(curl -sS https://storage.googleapis.com/kubernetes-release/release/stable.txt)
echo "K8S_VERSION : ${K8S_VERSION}"

# You can pass variables to minikube using MINIKUBE_ARGS
# If using tox you can export TOX_TESTENV_PASSENV.
# For example, you can run:
# $ export TOX_TESTENV_PASSENV="MINIKUBE_ARGS=--kubernetes-version=1.X.Y"
# now tox will run minikube with the specified flag
MINIKUBE_ARGS=${MINIKUBE_ARGS:-""}

echo "Starting docker service"
sudo systemctl enable docker.service
sudo systemctl start docker.service --ignore-dependencies
echo "Checking docker service"
sudo docker ps

echo "Download Kubernetes CLI"
wget -O kubectl "http://storage.googleapis.com/kubernetes-release/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
sudo chmod +x kubectl
sudo mv kubectl /usr/local/bin/

echo "Download minikube from minikube project"
wget -O minikube "https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64"
sudo chmod +x minikube
sudo mv minikube /usr/local/bin/

# L68-100: Set up minikube within Travis CI
# See https://github.com/kubernetes/minikube/blob/master/README.md#linux-continuous-integration-without-vm-support
echo "Set up minikube"
export MINIKUBE_WANTUPDATENOTIFICATION=false
export MINIKUBE_WANTREPORTERRORPROMPT=false
export CHANGE_MINIKUBE_NONE_USER=true
sudo mkdir -p $HOME/.kube
sudo mkdir -p $HOME/.minikube
sudo touch $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config
export MINIKUBE_HOME=$HOME
export MINIKUBE_DRIVER=${MINIKUBE_DRIVER:-none}

# Used bootstrapper to be kubeadm for the most recent k8s version
# since localkube is depreciated and only supported up to version 1.10.0
echo "Starting minikube"
sudo minikube start --vm-driver=$MINIKUBE_DRIVER --bootstrapper=kubeadm --logtostderr $MINIKUBE_ARGS

MINIKUBE_OK="false"

echo "Waiting for minikube to start..."
# this for loop waits until kubectl can access the api server that Minikube has created
for i in {1..90}; do # timeout for 3 minutes
   sudo kubectl get po &> /dev/null
   if [ $? -ne 1 ]; then
      MINIKUBE_OK="true"
      mkdir -P /home/runner/.kube
      sudo cp $HOME/.kube/config /home/runner/.kube/config
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
sudo kubectl get componentstatuses
sudo kubectl get configmaps
sudo kubectl get daemonsets
sudo kubectl get deployments
sudo kubectl get events
sudo kubectl get endpoints
sudo kubectl get horizontalpodautoscalers
sudo kubectl get ingress
sudo kubectl get jobs
sudo kubectl get limitranges
sudo kubectl get nodes
sudo kubectl get namespaces
sudo kubectl get pods
sudo kubectl get persistentvolumes
sudo kubectl get persistentvolumeclaims
sudo kubectl get quota
sudo kubectl get resourcequotas
sudo kubectl get replicasets
sudo kubectl get replicationcontrollers
sudo kubectl get secrets
sudo kubectl get serviceaccounts
sudo kubectl get services


echo "Running tests..."
set -x -e
# Yield execution to venv command
$*
