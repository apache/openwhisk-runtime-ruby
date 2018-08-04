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
          ErrorResponse.new 'The action did not return a dictionary.', 502
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