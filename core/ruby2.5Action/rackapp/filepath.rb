#!/usr/bin/ruby

module Filepath
  ROOT = '/action/'

  CONFIG = ROOT + '.wsk.config'
  TMP_ZIP = ROOT + 'action.zip'
  PARAM = ROOT + '.wsk.param'
  RESULT = ROOT + '.wsk.result'
  OUT = ROOT + '.wsk.stdout'
  ERR = ROOT + '.wsk.stderr'

  PROGRAM_DIR = ROOT + 'src/'
  RACKAPP_DIR = ROOT + 'rackapp/'
  ENTRYPOINT = PROGRAM_DIR + 'main.rb'
end
