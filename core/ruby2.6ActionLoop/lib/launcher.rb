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
require "logger"
require "json"

# requiring user's action code
require "./main__"

# open our file descriptor, this allows us to talk to the go-proxy parent process
# code gets executed via file descriptor #3
#out = File.for_fd(3)
out = IO.new(3)

# run this until process gets killed
while true
  # JSON arguments get passed via STDIN
  line = STDIN.gets()
  break unless line

  # parse JSON arguments that come in via the value parameter
  args = JSON.parse(line)
  payload = {}
  args.each do |key, value|
    if key == "value"
      payload = value
    else
      # set environment variables for other keys
      ENV["__OW_#{key.upcase}"] = value
    end
  end
  # execute the user's action code
  res = {}
  begin
    res = main(payload)
  rescue Exception => e
    puts "exception: #{e}"
    res ["error"] = "#{e}"
  end

  STDOUT.flush()
  STDERR.flush()
  out.puts(res.to_json)
  out.flush()
end
