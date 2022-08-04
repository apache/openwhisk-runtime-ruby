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

require "#{__dir__}/response/success.rb"
require "#{__dir__}/response/error.rb"
require "#{__dir__}/filepath.rb"

class RunApp
  include Filepath

  def call(env)
    if !File.exist? ENTRYPOINT then
      return ErrorResponse.new 'Invalid Action: no action file found', 500
    end

    # Set environment variables
    body = Rack::Request.new(env).body.read
    data = JSON.parse(body) || {}
    env = {'BUNDLE_GEMFILE' => PROGRAM_DIR + 'Gemfile'}
    data.each do |key, value|
      if key != 'value'
        env["__OW_#{key.upcase}"] = value if value && value.is_a?(String)
      end
    end

    # Save parameter values to file in order to let runner.rb read this later
    File.write PARAM, data['value'].to_json

    # Execute the action with given parameters
    if system(env, "bundle exec ruby -r #{ENTRYPOINT} #{RACKAPP_DIR}runner.rb | tee #{OUT}") then
      if File.exist? RESULT then
        result = File.read(RESULT)
        if valid_json?(result) then
          SuccessResponse.new(JSON.parse(result))
        else
          warn "Result must be an array but has type '#{result.class.to_s}': #{result}"
          ErrorResponse.new 'The action did not return a dictionary or array.', 502
        end
      else
        ErrorResponse.new 'Invalid Action: An error occurred running the action', 502
      end
    else
      ErrorResponse.new "Invalid Action: the execution was not successful. / #{File.read(OUT)}}", 502
    end
  end

  private
    def valid_json?(json)
      JSON.parse(json).class == Hash
    rescue
      false
    end
end
