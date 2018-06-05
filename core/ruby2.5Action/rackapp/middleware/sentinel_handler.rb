require "#{__dir__}/base.rb"

class SentinelHandler < MiddlewareBase
  def call(env)
    response = @app.call(env)
    RackHelper.log response.status.to_json
    if !(env['REQUEST_PATH'] == '/init' && response.status == 200) then
      puts response.body if response.status!=200
      puts "XXX_THE_END_OF_A_WHISK_ACTIVATION_XXX"
      warn "XXX_THE_END_OF_A_WHISK_ACTIVATION_XXX"
    end
    response
  end
end