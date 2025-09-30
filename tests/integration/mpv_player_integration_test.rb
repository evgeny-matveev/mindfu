# frozen_string_literal: true

require_relative "../test_helper"

module MeditationPlayer
  class MPVPlayerIntegrationTest < Test
    def setup
      @player = MPVPlayer.new
    end

    def teardown
      @player.stop
    end

    def test_mpv_process_spawns_successfully
      refute_empty @player.audio_files, "Should have audio files available"

      file = @player.audio_files.first
      @player.play(file)

      # Give process time to spawn
      sleep 0.5

      # Process should be running (not defunct)
      pid = @player.instance_variable_get(:@mpv_pid)
      assert pid, "MPV process should have been spawned"

      # Check if process exists and is not defunct
      process_info = `ps -p #{pid} -o state=`.strip
      refute_equal "Z", process_info, "MPV process should not be defunct"

      @player.stop
    end

    def test_mpv_socket_is_created
      refute_empty @player.audio_files, "Should have audio files available"

      file = @player.audio_files.first
      @player.play(file)

      # Give process more time to spawn and create socket
      sleep 2.0

      socket_path = @player.instance_variable_get(:@mpv_socket)
      assert socket_path, "MPV socket path should be set"

      # Check if socket exists with a more informative message
      if File.exist?(socket_path)
        assert_path_exists socket_path, "MPV socket file should exist"
      else
        flunk "MPV socket file does not exist at #{socket_path}. " \
              "Process PID: #{@player.instance_variable_get(:@mpv_pid)}"
      end

      @player.stop

      # Socket should be cleaned up after stop
      refute_path_exists socket_path, "MPV socket should be cleaned up after stop"
    end

    def test_mpv_command_uses_valid_options
      # Verify that the command uses only valid mpv options
      refute_empty @player.audio_files, "Should have audio files available"

      file = @player.audio_files.first

      # Mock the spawn method to capture the actual command
      actual_command = nil
      @player.define_singleton_method(:spawn) do |*args|
        actual_command = args
        # Return a valid PID for testing
        12_345
      end

      @player.play(file)

      # Verify the command was called
      assert actual_command, "Spawn should have been called"
      command_string = actual_command.join(" ")

      # Should include valid options
      assert_includes command_string, "--no-video", "Command should include --no-video"
      assert_includes command_string, "--input-ipc-server",
                      "Command should include --input-ipc-server"
    end

    def test_mpv_command_excludes_invalid_options
      refute_empty @player.audio_files, "Should have audio files available"

      file = @player.audio_files.first

      # Mock the spawn method to capture the actual command
      actual_command = nil
      @player.define_singleton_method(:spawn) do |*args|
        actual_command = args
        # Return a valid PID for testing
        12_345
      end

      @player.play(file)

      # Verify the command was called
      assert actual_command, "Spawn should have been called"
      command_string = actual_command.join(" ")

      # Should NOT include invalid options
      refute_includes command_string, "--autoexit", "Command should NOT include --autoexit"
      refute_includes command_string, "--loglevel=quiet",
                      "Command should NOT include --loglevel=quiet"
    end

    def test_mpv_command_sets_valid_pid
      refute_empty @player.audio_files, "Should have audio files available"

      file = @player.audio_files.first

      # Mock the spawn method to capture the actual command
      @player.define_singleton_method(:spawn) do |*_args|
        # Return a valid PID for testing
        12_345
      end

      @player.play(file)

      pid = @player.instance_variable_get(:@mpv_pid)
      assert_equal 12_345, pid, "Valid PID should be set"
    end
  end
end
