#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "test_helper"

# Simple script to run all tests
# Find all test files in current directory and subdirectories
test_files = Dir.glob("**/*_test.rb")

# Also include the ninety_percent_rule_verification.rb file
if File.exist?("ninety_percent_rule_verification.rb")
  test_files += ["ninety_percent_rule_verification.rb"]
end

test_files.each do |test_file|
  puts "Running #{test_file}..."
  system("ruby -Ilib #{test_file}")
  puts "-" * 50
end

# Final cleanup of any remaining processes
puts "Performing final cleanup..."

# Find and kill any mpv processes that might be running
mpv_pids = `ps aux | grep mpv | grep -v grep | awk '{print $2}'`.split
puts "Found #{mpv_pids.length} mpv processes to clean up..." if mpv_pids.any?

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

puts "No mpv processes found to clean up." if mpv_pids.empty?
puts "Cleanup completed."
