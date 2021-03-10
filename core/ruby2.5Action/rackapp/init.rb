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

class InitApp
  include Filepath

  def call(env)
    # Make sure that this action is not initialised more than once
    if File.exist? CONFIG
      puts 'Error: Cannot initialize the action more than once.'
      $stdout.flush
      return ErrorResponse.new 'Cannot initialize the action more than once.', 403
    end

    # Expect JSON data input
    body = Rack::Request.new(env).body.read
    data = JSON.parse(body)['value'] || {}

    # Is the input data empty?
    return ErrorResponse.new 'Missing main/no code to execute.', 500 if data == {}

    name = data['name'] || ''           # action name
    main = data['main'] || ''           # function to call
    code = data['code'] || ''           # source code to run
    binary = data['binary'] || false    # code is binary?

    # Are name/main/code variables instance of String?
    if ![name, main, code].map {|e| e.is_a? String }.inject {|a, b| a && b }
      return ErrorResponse.new 'Invalid Parameters: failed to handle the request', 500
    end

    env = { 'BUNDLE_GEMFILE' => "#{PROGRAM_DIR}Gemfile" }
    if binary
      File.write TMP_ZIP, Base64.decode64(code)
      if !unzip(TMP_ZIP, PROGRAM_DIR)
        return ErrorResponse.new
'Invalid Binary: failed to open zip file. Please make sure you have finished $bundle package successfully.', 500
      end

      # Try to resolve dependencies
      if File.exist?("#{PROGRAM_DIR}Gemfile")
        if !File.directory?("#{PROGRAM_DIR}vendor/cache")
          return ErrorResponse.new
'Invalid Binary: vendor/cache folder is not found. Please make sure you have used valid zip binary.', 200
        end
        if !system(env, "bundle install --local 2> #{ERR} 1> #{OUT}")
          return ErrorResponse.new
"Invalid Binary: failed to resolve dependencies / #{File.read(OUT)} / #{File.read(ERR)}", 500
        end
      else
        File.write env['BUNDLE_GEMFILE'], '' # For better performance, better to remove Gemfile and remove "bundle exec" redundant call when binary=false. To be improved in future.
      end
      if !File.exist?(ENTRYPOINT)
        return ErrorResponse.new 'Invalid Ruby Code: zipped actions must contain main.rb at the root.', 500
      end
    else
      # Save the code for future use
      File.write ENTRYPOINT, code
      File.write env['BUNDLE_GEMFILE'], '' # For better performance, better to remove Gemfile and remove "bundle exec" redundant call when binary=false. To be improved in future.
    end

    # Check if the ENTRYPOINT code is valid or not
    return ErrorResponse.new 'Invalid Ruby Code: failed to parse the input code', 500 if !valid_code?(ENTRYPOINT)

    # Check if the method exists as expected
    if !system(env,
"bundle exec ruby -r #{ENTRYPOINT} -e \"method(:#{main}) ? true : raise(Exception.new('Error'))\" 2> #{ERR} 1> #{OUT}")
      return ErrorResponse.new "Invalid Ruby Code: method checking failed / #{File.read(OUT)} / #{File.read(ERR)}", 500
    end

    # Save config parameters to filesystem so that later /run can use this
    File.write CONFIG, { :main => main, :name => name }.to_json

    # Proceed with the next step
    SuccessResponse.new({ 'OK' => true })
  end

  private

  def valid_code?(path)
    system("ruby -e 'RubyVM::InstructionSequence.compile_file(\"#{path}\")' 2> #{ERR} 1> #{OUT}")
  rescue StandardError
    false
  end

  def unzip(zipfile_path, destination_folder)
    Zip::File.open(zipfile_path) do |zip|
      zip.each do |file|
        f_path = destination_folder + file.name
        FileUtils.mkdir_p(File.dirname(f_path))
        zip.extract(file, f_path)
      end
    end
    true
  rescue StandardError
    false
  end
end
