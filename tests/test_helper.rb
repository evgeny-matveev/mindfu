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
      # Find and kill any mpv processes that might be running
      begin
        mpv_pids = `ps aux | grep mpv | grep -v grep | awk '{print $2}'`.split
        mpv_pids.each do |pid|
          next if pid.empty?
          begin
            Process.kill("TERM", pid.to_i)
            # Wait a bit for graceful termination
            sleep 0.1
            # Force kill if still running
            Process.kill("KILL", pid.to_i)
          rescue Errno::ESRCH, Errno::EPERM
            # Process already terminated or no permission
          end
        end
      rescue => e
        # Ignore errors in cleanup
      end
    end

    def cleanup_recently_played_file
      # Clean up the test-specific recently played file to ensure test isolation
      test_recently_played_file = "tmp/test_recently_played.json"
      File.delete(test_recently_played_file) if File.exist?(test_recently_played_file)
    rescue => e
      # Ignore errors in cleanup
    end
  end
end
