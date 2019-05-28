require 'peastash/log_device'

class Peastash
  module Outputs
    class IO
      @@default_io = STDOUT

      def self.default_io
        @@default_io
      end

      def initialize(file, *args)
        dir = File.realpath(File.dirname(file))
        name = File.basename(file)
        @device = ::Peastash::LogDevice.new("#{dir}/#{name}", *args)
      end

      def dump(event)
        @device.write(event.to_json + "\n")
      end
    end
  end
end
