# frozen_string_literal: true

require "minitest/autorun"
require "minitest/pride"
require_relative "../lib/meditation_player"

module MeditationPlayer
  class Test < Minitest::Test
    def setup
      # Clean up any existing mpv processes before each test
      cleanup_mpv_processes
      # Clean up recently played file state
      cleanup_recently_played_file
      super
    end

    def teardown
      # Clean up any mpv processes after each test
      cleanup_mpv_processes
      # Clean up recently played file state
      cleanup_recently_played_file
      super
    end

    private

    def cleanup_mpv_processes
      cleanup_mpv_process_group
    end

    def cleanup_mpv_process_group(verbose: false)
      # Find and kill any mpv processes that might be running

      mpv_pids = `ps aux | grep mpv | grep -v grep | awk '{print $2}'`.split
      puts "Found #{mpv_pids.length} mpv processes to clean up..." if verbose && mpv_pids.any?

      mpv_pids.each do |pid|
        next if pid.empty?

        begin
          Process.kill("TERM", pid.to_i)
          # Wait a bit for graceful termination
          sleep 0.1
          # Force kill if still running
          Process.kill("KILL", pid.to_i)
          puts "Terminated mpv process #{pid}" if verbose
        rescue Errno::ESRCH, Errno::EPERM
          # Process already terminated or no permission
        end
      end

      puts "No mpv processes found to clean up." if verbose && mpv_pids.empty?
    rescue StandardError => e
      puts "Error during cleanup: #{e.message}" if verbose
    end

    def cleanup_recently_played_file
      # Clean up the test-specific recently played file to ensure test isolation
      test_recently_played_file = "tmp/test_recently_played.json"
      FileUtils.rm_f(test_recently_played_file)
    rescue StandardError
      # Ignore errors in cleanup
    end
  end
end
