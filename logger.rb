require 'logger'

module Gaudi
  @@logger = Logger.new(STDOUT)

  def self.logger
    @@logger
  end
end