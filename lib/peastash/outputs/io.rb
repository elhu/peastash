require 'peastash/log_device'

class Peastash
  module Outputs
    class IO
      @@default_io = STDOUT

      def self.default_io
        @@default_io
      end

      def initialize(file, *args)
        file = if file.is_a?(String)
                 dir = File.realpath(File.dirname(file))
                 name = File.basename(file)
                 "#{dir}/#{name}"
               end
        @device = ::Peastash::LogDevice.new(file, *args)
      end

      def dump(event)
        @device.write(event.to_json + "\n")
      end
    end
  end
end
