#!/usr/bin/env ruby

# Simple script to run all tests
Dir.glob("tests/*_test.rb").each do |test_file|
  puts "Running #{test_file}..."
  system("ruby -Ilib #{test_file}")
  puts "-" * 50
end