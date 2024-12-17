require 'optparse'
require './controller'

module Gaudi
  options = {}

  OptionParser.new do |opts|
    opts.banner = "Usage: gaudi.rb [options]"

    opts.on("-a", "--action ACTION", "Action: install, report or uninstall", String) do |action|
      options[:action] = action
    end

    opts.on("-d", "--database db1,db2", "Set you db names from config.yml", Array) do |databases|
      options[:databases] = databases
    end

    opts.on("-h", "--help", "Prints this help") do
      puts opts
      exit
    end
  end.parse!(ARGV)

  Controller.new(user_options: options).call
end