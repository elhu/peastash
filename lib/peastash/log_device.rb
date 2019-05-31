require 'logger'
require 'fileutils'

class Peastash
  class LogDevice < ::Logger::LogDevice
    def open_logfile(filename)
      super
    rescue Errno::EACCES
      stat_data = File.stat(filename) rescue nil
      STDERR.puts "[#{Time.now}][#{Process.pid}] Could not open #{filename} for writing, recreating it. Info: #{stat_data.inspect}"
      FileUtils.rm(filename)
      create_logfile(filename)
    rescue Errno::ENOENT => e
      require 'tempfile'
      temp_file = Tempfile.new([filename, '.log'])
      STDERR.puts "[#{Time.now}][#{Process.pid}] Could not open #{filename} for writing: #{e.message}. Data will be writen in: #{temp_file.path}"
      open_logfile(temp_file.path)
    end
  end
end
