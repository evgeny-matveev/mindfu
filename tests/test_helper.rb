# frozen_string_literal: true

require "minitest/autorun"
require "minitest/pride"
require "fileutils"
require_relative "../lib/meditation_player"

# Set test environment variable
ENV["TEST"] = "true"

module MeditationPlayer
  class Test < Minitest::Test
    def setup
      # Clean up any existing mpv processes before each test
      cleanup_mpv_processes
      super
    end

    def teardown
      # Clean up any mpv processes after each test
      cleanup_mpv_processes
      super
    end

    # Common mocking helper for MPV player
    def mock_mpv_spawn
      mock = Minitest::Mock.new
      mock.expect(:spawn, 123) # Simulate process ID
      mock.expect(:wait, true) # Simulate successful process wait
      mock
    end

    # Mock Process.spawn behavior for testing
    def mock_process_spawn(_command)
      # Return a mock process that can be controlled
      Object.new.tap do |mock_process|
        def mock_process.spawn(*_args)
          123 # Mock process ID
        end

        def mock_process.wait?
          true # Mock successful wait
        end
      end
    end

    # Mock Process.kill behavior for testing
    def mock_process_kill?(_signal, _pid)
      # Simulate successful kill
      true
    end

    # Create a temporary audio file for testing
    def create_temp_audio_file(content = "dummy audio content", filename = "test_audio.mp3")
      temp_dir = "tmp"
      FileUtils.mkdir_p(temp_dir) unless File.directory?(temp_dir)

      temp_file = File.join(temp_dir, filename)
      File.write(temp_file, content)
      temp_file
    ensure
      # Clean up the temp file after test
      FileUtils.rm_f(temp_file)
    end

    # Mock file selector for testing random file selection
    def mock_file_selector(_files = ["file1.mp3", "file2.mp3", "file3.mp3"])
      selector = Object.new
      def selector.select_random_file
        files.sample
      end
      selector
    end

    # Common assertion for state transitions
    def assert_state_transition(state_machine, from_state, to_state, event)
      assert_equal from_state, state_machine.current_state
      state_machine.fire(event)
      assert_equal to_state, state_machine.current_state
    end

    # Common assertion for process cleanup
    def assert_no_mpv_processes
      mpv_pids = `ps aux | grep mpv | grep -v grep | awk '{print $2}'`.split
      assert_empty mpv_pids, "Found #{mpv_pids.length} mpv processes still running"
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
  end
end
