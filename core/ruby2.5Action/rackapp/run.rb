require "#{__dir__}/response/success.rb"
require "#{__dir__}/response/error.rb"
require "#{__dir__}/filepath.rb"

class RunApp
  def call(env) 
    RackHelper.log "YES"
    if !File.exist? Filepath::ENTRYPOINT then
      return ErrorResponse.new 'Invalid Action: no action file found', 500
    end

    # Set environment variables
    RackHelper.log "NO"
    body = Rack::Request.new(env).body.read
    data = JSON.parse(body) || {}
    env = {'BUNDLE_GEMFILE' => Filepath::PROGRAM_DIR + 'Gemfile'}
    ['api_key', 'namespace', 'action_name', 'activation_id', 'deadline'].each{|e|
      env["__OW_#{e.upcase}"] = data[e] if data[e] && data[e].is_a?(String)
    }

    # Save parameter values to file in order to let runner.rb read this later
    File.write Filepath::PARAM, data['value'].to_json

    # Execute the action with given parameters
    RackHelper.log File.read(Filepath::PARAM)
    if system(env, "bundle exec ruby -r #{Filepath::ENTRYPOINT} #{Filepath::RACKAPP_DIR}runner.rb | tee #{Filepath::OUT}") then
      if File.exist? Filepath::RESULT then
        result = File.read(Filepath::RESULT)
        RackHelper.log result
        if valid_json?(result) then
          RackHelper.log "B"
          SuccessResponse.new(JSON.parse(result))
        else
          RackHelper.log "C"
          warn "Result must be an array but has type '#{result.class.to_s}': #{result}"
          ErrorResponse.new 'The action did not return a dictionary.', 502
        end
      else
        ErrorResponse.new 'Invalid Action: An error occurred running the action', 502
      end
    else
      RackHelper.log File.read(Filepath::OUT) || "(No stdout found)"
      ErrorResponse.new "Invalid Action: the execution was not successful. / #{File.read(Filepath::OUT)}}", 502
    end
  end

  private
    def valid_json?(json)
      JSON.parse(json).class == Hash
    rescue
      false
    end
end