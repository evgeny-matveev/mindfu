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

# Use the shared cleanup method from test_helper
MeditationPlayer::Test.new.cleanup_mpv_process_group(verbose: true)

puts "Cleanup completed."
