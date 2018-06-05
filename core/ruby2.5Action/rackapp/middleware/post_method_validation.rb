require "#{__dir__}/base.rb"

class HTTPPostMethodValidation < MiddlewareBase
  def call(env)
    if Rack::Request.new(env).request_method == 'POST' then
      @app.call(env)
    else
      Rack::Response.new 'Something went wrong with the request', 500
    end
  end
end  