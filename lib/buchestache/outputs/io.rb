require 'logger'

class Buchestache
  module Outputs
    class IO
      @@default_io = STDOUT

      def self.default_io
        @@default_io
      end

      def initialize(file)
        @device = Logger::LogDevice.new(file)
      end

      def dump(event)
        @device.write(event.to_json + "\n")
      end
    end
  end
end
