#!/usr/bin/ruby

require 'rubygems'
require 'json'
require 'zip'
require 'base64'

#====== For Debugging Purpose Only
module RackHelper
  require 'uri'
  require 'net/http'
  class << self
    def _p(name, value)
      "#{name}: #{value}\n\n-------\n"
    end

    def log(value)
      url = URI("http://SOME_URL_SUCH_AS_MOCKBIN/")
      http = Net::HTTP.new(url.host, url.port)

      req = Net::HTTP::Post.new(url)
      req["accept"] = 'application/json'
      req["content-type"] = 'application/x-www-form-urlencoded'
      req.body = value
      response = http.request(req)
    end

    def debug(env)
      request = Rack::Request.new(env)
      log _p(:ENV, ENV.to_a) +
        _p(:request_params, request.params.to_a) + 
        _p(:request_env, request.env) + 
        _p(:request_POST, request.POST) + 
        _p(:body, request.body.read)
    end

  end
end
#====== For Debugging Purpose Only

require "#{__dir__}/rackapp/middleware/post_method_validation.rb"
require "#{__dir__}/rackapp/middleware/sentinel_handler.rb"
require "#{__dir__}/rackapp/init.rb"
require "#{__dir__}/rackapp/run.rb"

rackapp = Rack::Builder.app do
  use HTTPPostMethodValidation
  use SentinelHandler

  #  {
  #    "value":{
  #      "name":   "myAction",
  #      "binary": false,
  #      "main":   "main",
  #      "code":   "def main(params) {\\n  {payload: \\\"length = \\\" + params.to_s}\\n}\\n\"
  #    }
  #  }
  map '/init' do
    run InitApp.new
  end

  #  {
  #    "activation_id":    "91f9fa332a424e35b9fa332a423e35fd",
  #    "action_name":      "/guest/myAction",
  #    "deadline":         "1526980345727",
  #    "api_key":          "23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP",
  #    "value":            {\"message\":\"hello\"},
  #    "namespace":        "guest"
  #  }
  map "/run" do
    run RunApp.new
  end
end

run rackapp