require "#{__dir__}/response/success.rb"
require "#{__dir__}/response/error.rb"
require "#{__dir__}/filepath.rb"

class InitApp
  def call(env) 
    # RackHelper.debug env
    # Expect JSON data input
    body = Rack::Request.new(env).body.read
    RackHelper.log body
    data = JSON.parse(body)['value'] || {}
    name = data['name'] || ''           # action name
    main = data['main'] || ''           # function to call
    code = data['code'] || ''           # source code to run
    binary = data['binary'] || false    # code is binary?

    # Are name/main/code variables instance of String?
    if ![name, main, code].map{|e| e.is_a? String }.inject{|a,b| a && b } then
      return ErrorResponse.new 'Invalid Parameters: failed to handle the request', 500
    end

    RackHelper.log env.to_json
    env = {'BUNDLE_GEMFILE' => Filepath::PROGRAM_DIR + 'Gemfile'}
    if binary then
      File.write Filepath::TMP_ZIP, Base64.decode64(code)
      if !unzip(Filepath::TMP_ZIP, Filepath::PROGRAM_DIR) then
        return ErrorResponse.new 'Invalid Binary: failed to open zip file. Please make sure you have finishied $bundle package successfully.', 500
      end
      RackHelper.log `ls -alR #{Filepath::PROGRAM_DIR}`
      # Try to resolve dependencies
      if File.exist?(Filepath::PROGRAM_DIR + 'Gemfile') then
        if !File.directory?(Filepath::PROGRAM_DIR + 'vendor/cache') then
          return ErrorResponse.new 'Invalid Binary: vendor/cache folder is not found. Please make sure you have used valid zip binary.', 200
        end
        if !system(env, "bundle install --local 2> #{Filepath::ERR} 1> #{Filepath::OUT}") then
          return ErrorResponse.new "Invalid Binary: failed to resolve dependencies / #{File.read(Filepath::OUT)} / #{File.read(Filepath::ERR)}", 500
        end
      else
        File.write env['BUNDLE_GEMFILE'], ''  # For better performance, better to remove Gemfile and remove "bundle exec" redundant call when binary=false. To be improved in future.
      end
      if !File.exist?(Filepath::ENTRYPOINT) then
        return ErrorResponse.new 'Invalid Ruby Code: zipped actions must contain main.rb at the root.', 500
      end
    else
      # Save the code for future use
      File.write Filepath::ENTRYPOINT, code
      File.write env['BUNDLE_GEMFILE'], ''  # For better performance, better to remove Gemfile and remove "bundle exec" redundant call when binary=false. To be improved in future.
    end

    # Check if the ENTRYPOINT code is valid or not
    RackHelper.log "TRACK-Zero"
    if !valid_code?(Filepath::ENTRYPOINT) then
      RackHelper.log "TRACK-alpha / #{File.read(Filepath::OUT)} / #{File.read(Filepath::ERR)}"
      return ErrorResponse.new 'Invalid Ruby Code: failed to parse the input code', 500
    end

    RackHelper.log "TRACK-A"
    # Check if the method exists as expected
    if !system(env, "bundle exec ruby -r #{Filepath::ENTRYPOINT} -e \"method(:#{main}) ? true : raise(Exception.new('Error'))\" 2> #{Filepath::ERR} 1> #{Filepath::OUT}") then
      return ErrorResponse.new "Invalid Ruby Code: method checking failed / #{File.read(Filepath::OUT)} / #{File.read(Filepath::ERR)}", 500
    end

    RackHelper.log "TRACK-B"
    # Save config parameters to filesystem so that later /run can use this
    File.write Filepath::CONFIG, {:main=>main, :name=>name}.to_json

    # Proceed with the next step
    SuccessResponse.new({'OK'=>true})
  end

  private
    def valid_code?(path)
      system("ruby -e 'RubyVM::InstructionSequence.compile_file(\"#{path}\")' 2> #{Filepath::ERR} 1> #{Filepath::OUT}")
    rescue
      false
    end

    def unzip(zipfile_path, destination_folder)
      Zip::File.open(zipfile_path) do |zip|
        zip.each do |file|
          zip.extract(file, destination_folder + file.name)
        end
      end
      true
    rescue
      false
    end
end