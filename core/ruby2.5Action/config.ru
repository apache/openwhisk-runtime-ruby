#!/usr/bin/ruby

require 'rubygems'
require 'json'
require 'zip'
require 'base64'
require "#{__dir__}/rackapp/middleware/post_method_validation.rb"
require "#{__dir__}/rackapp/middleware/sentinel_handler.rb"
require "#{__dir__}/rackapp/init.rb"
require "#{__dir__}/rackapp/run.rb"

rackapp = Rack::Builder.app do
  use HTTPPostMethodValidation
  use SentinelHandler

  map '/init' do
    run InitApp.new
  end

  map "/run" do
    run RunApp.new
  end
end

run rackapp