require 'peastash/log_device'

class Peastash
  module Outputs
    class IO
      @@default_io = STDOUT

      def self.default_io
        @@default_io
      end

      ruby2_keywords def initialize(file, *args)
        if file.is_a?(String)
          # Rewrite symlink path to realpath for instance
          # /home/app/releases/20190528155050/log/logstash.log -> /home/app/shared/log/logstash.log
          # if the symlinked folder gets deleted on further releases, the log rotation will fail with
          # a long wait ending with : log rotation inter-process lock failed.
          # realpath is called without the filename because it expects the full path to exists
          dir = File.realpath(File.dirname(file))
          name = File.basename(file)
          file = "#{dir}/#{name}"
        end
        @device = ::Peastash::LogDevice.new(file, *args)
      end

      def dump(event)
        @device.write(event.to_json + "\n")
      end
    end
  end
end
