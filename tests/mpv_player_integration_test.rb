# frozen_string_literal: true

require_relative "test_helper"

module MeditationPlayer
  class MPVPlayerIntegrationTest < Test
    def setup
      @player = MPVPlayer.new
    end

    def teardown
      @player.stop
    end

    def test_playback_actually_works
      # This test verifies that audio actually plays
      skip "Test requires actual audio playback - manual verification needed"

      # For manual testing:
      # 1. Run this test with audio output enabled
      # 2. Listen to ensure audio plays
      # 3. Verify no zombie processes are created
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

      # Give process time to spawn and create socket
      sleep 0.5

      socket_path = @player.instance_variable_get(:@mpv_socket)
      assert socket_path, "MPV socket path should be set"
      assert File.exist?(socket_path), "MPV socket file should exist"

      @player.stop

      # Socket should be cleaned up after stop
      refute File.exist?(socket_path), "MPV socket should be cleaned up after stop"
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
        12345
      end

      @player.play(file)

      # Verify the command was called
      assert actual_command, "Spawn should have been called"
      command_string = actual_command.join(" ")

      # Should include valid options
      assert_includes command_string, "--no-video", "Command should include --no-video"
      assert_includes command_string, "--input-ipc-server", "Command should include --input-ipc-server"

      # Should NOT include invalid options
      refute_includes command_string, "--autoexit", "Command should NOT include --autoexit"
      refute_includes command_string, "--loglevel=quiet", "Command should NOT include --loglevel=quiet"

      pid = @player.instance_variable_get(:@mpv_pid)
      assert_equal 12345, pid, "Valid PID should be set"
    end
  end
end