#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e

# upgrade docker
sudo sh -c 'echo "deb https://apt.dockerproject.org/repo ubuntu-precise main" > /etc/apt/sources.list.d/docker.list'
sudo apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
sudo apt-get update
sudo apt-key update
sudo apt-get -qqy -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install docker-engine=1.11.1-0~precise

# Build script for Travis-CI.

SCRIPTDIR=$(cd $(dirname "$0") && pwd)
ROOTDIR="$SCRIPTDIR/../.."
HOMEDIR="$SCRIPTDIR/../../../"

# clone OpenWhisk utilities repo. in order to run scanCode
cd $HOMEDIR
git clone https://github.com/apache/incubator-openwhisk-utilities.git

# clone main openwhisk repo. for testing purposes
git clone --depth=1 https://github.com/apache/incubator-openwhisk.git openwhisk
cd openwhisk
./tools/travis/setup.sh
