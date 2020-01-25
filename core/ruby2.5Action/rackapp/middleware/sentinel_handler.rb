require "#{__dir__}/base.rb"

class SentinelHandler < MiddlewareBase
  def call(env)
    response = @app.call(env)
    if !(env['REQUEST_PATH'] == '/init' && [200,403].include?(response.status)) then
      puts response.body if response.status!=200
      puts "XXX_THE_END_OF_A_WHISK_ACTIVATION_XXX"
      warn "XXX_THE_END_OF_A_WHISK_ACTIVATION_XXX"
      STDOUT.flush
      STDERR.flush
    end
    response
  end
end
