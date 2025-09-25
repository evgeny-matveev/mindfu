#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "test_helper"

# Simple script to run all tests
Dir.glob("tests/*_test.rb").each do |test_file|
  puts "Running #{test_file}..."
  system("ruby -Ilib #{test_file}")
  puts "-" * 50
end

# Final cleanup of any remaining processes
puts "Performing final cleanup..."

# Find and kill any mpv processes that might be running
begin
  mpv_pids = `ps aux | grep mpv | grep -v grep | awk '{print $2}'`.split
  if mpv_pids.any?
    puts "Found #{mpv_pids.length} mpv processes to clean up..."
    mpv_pids.each do |pid|
      next if pid.empty?
      begin
        Process.kill("TERM", pid.to_i)
        # Wait a bit for graceful termination
        sleep 0.1
        # Force kill if still running
        Process.kill("KILL", pid.to_i)
        puts "Terminated mpv process #{pid}"
      rescue Errno::ESRCH, Errno::EPERM
        # Process already terminated or no permission
      end
    end
  else
    puts "No mpv processes found to clean up."
  end
rescue => e
  puts "Error during cleanup: #{e.message}"
end

puts "Cleanup completed."
