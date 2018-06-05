#!/usr/bin/ruby

require 'json'
require "#{__dir__}/filepath.rb"

include Filepath
config = JSON.parse(File.read(CONFIG))
param = JSON.parse(File.read(PARAM))
File.write RESULT, method(config["main"]).call(param).to_json
