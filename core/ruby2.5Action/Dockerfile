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
FROM ruby:2.5

# install dependencies
RUN gem install \
        bundler \
        rubyzip \
        rack \
        puma \
        rake          `#optional` \
        mechanize     `#optional` \
        activesupport `#optional` \
        jwt           `#optional`

# create src directory to store action files
RUN mkdir -p /action/src
ADD rackapp /action/rackapp/
COPY config.ru /action

# run webserver
RUN cd /action
EXPOSE 8080
ENV BUNDLE_GEMFILE /action/src/Gemfile
ENV RUBYOPT -EUTF-8
CMD [ "puma", "/action/config.ru", "-b", "tcp://0.0.0.0:8080" ]
