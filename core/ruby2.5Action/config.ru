#!/usr/bin/ruby

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

require 'rubygems'
require 'json'
require 'zip'
require 'base64'
require "#{__dir__}/rackapp/middleware/post_method_validation.rb"
require "#{__dir__}/rackapp/middleware/sentinel_handler.rb"
require "#{__dir__}/rackapp/init.rb"
require "#{__dir__}/rackapp/run.rb"

rackapp = Rack::Builder.app do
  use HTTPPostMethodValidation
  use SentinelHandler

  map '/init' do
    run InitApp.new
  end

  map '/run' do
    run RunApp.new
  end
end

run rackapp
