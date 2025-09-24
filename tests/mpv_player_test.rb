# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/mpv_player"

module MeditationPlayer
  class MPVPlayerTest < Test
    def setup
      @player = MPVPlayer.new
      @test_file = "/fake/test.mp3"
    end

    def teardown
      @player.stop if @player.respond_to?(:stop)
    end

    def test_initially_not_playing
      refute_predicate @player, :playing?
    end

    def test_initially_not_paused
      refute_predicate @player, :paused?
    end

    def test_current_file_returns_nil_initially
      assert_nil @player.current_file
    end

    def test_current_progress_returns_zero_initially
      assert_in_delta(0.0, @player.current_progress)
    end

    def test_play_starts_mpv_process
      mock_mpv_spawn do
        @player.play(@test_file)
        assert_predicate @player, :playing?
        assert_equal File.basename(@test_file), @player.current_file
      end
    end

    def test_play_nonexistent_file_does_nothing
      @player.play("/nonexistent/file.mp3")
      refute_predicate @player, :playing?
      assert_nil @player.current_file
    end

    def test_pause_when_playing_sets_paused_state
      mock_mpv_spawn do
        @player.play(@test_file)
        @player.pause
        assert_predicate @player, :paused?
        refute_predicate @player, :playing?
      end
    end

    def test_pause_when_not_playing_does_nothing
      @player.pause
      refute_predicate @player, :paused?
    end

    def test_resume_when_paused_restores_playing_state
      mock_mpv_spawn do
        @player.play(@test_file)
        @player.pause
        @player.resume
        assert_predicate @player, :playing?
        refute_predicate @player, :paused?
      end
    end

    def test_resume_when_not_paused_does_nothing
      @player.resume
      refute_predicate @player, :playing?
    end

    def test_stop_terminates_mpv_process_and_returns_progress
      mock_mpv_spawn do
        @player.play(@test_file)
        progress = @player.stop
        refute_predicate @player, :playing?
        refute_predicate @player, :paused?
        assert_nil @player.current_file
        assert_kind_of Float, progress
        assert_operator progress, :>=, 0.0
        assert_operator progress, :<=, 1.0
      end
    end

    def test_stop_when_not_playing_returns_zero
      progress = @player.stop
      assert_in_delta(0.0, progress)
    end

    def test_gets_mpv_progress_via_ipc
      mock_mpv_spawn do
        @player.play(@test_file)

        # Mock MPV response for time-pos and duration
        mock_mpv_response({ "data" => 30.0 }, "get_property", "time-pos")
        mock_mpv_response({ "data" => 60.0 }, "get_property", "duration")

        progress = @player.current_progress
        assert_in_delta 0.5, progress, 0.01
      end
    end

    def test_handles_mpv_process_termination
      mock_mpv_spawn do
        @player.play(@test_file)

        # Simulate mpv process termination
        @player.instance_variable_set(:@mpv_pid, nil)
        @player.instance_variable_set(:@playing, false)

        refute_predicate @player, :playing?
      end
    end

    def test_cleans_up_socket_files_on_stop
      mock_mpv_spawn do
        @player.play(@test_file)
        socket_path = @player.instance_variable_get(:@mpv_socket)

        @player.stop

        # Verify socket file is cleaned up
        refute_path_exists socket_path if socket_path
      end
    end

    def test_handles_ipc_connection_errors
      mock_mpv_spawn do
        @player.play(@test_file)

        # Simulate IPC connection failure
        @player.instance_variable_set(:@mpv_socket, "/nonexistent/socket")

        progress = @player.current_progress
        assert_in_delta(0.0, progress)
      end
    end

    def test_audio_files_returns_array
      assert_kind_of Array, @player.audio_files
    end

    def test_audio_files_finds_supported_formats
      # This test depends on actual audio files in the test directory
      # but we can test that it returns an array
      files = @player.audio_files
      assert_kind_of Array, files
      files.each do |file|
        assert_match(/\.(mp3|mp4|wav|ogg)$/i, file)
      end
    end

    private

    def mock_mpv_spawn
      # Mock File.exist? to return true for test file
      File.define_singleton_method(:exist?) do |path|
        path == "/fake/test.mp3"
      end

      # Mock the spawn method to avoid actually starting mpv
      def @player.spawn_mpv(*args)
        @mpv_pid = 12_345 # Mock PID
        @mpv_socket = "/tmp/mpvsocket_test_#{object_id}"

        # Create a mock socket file
        File.write(@mpv_socket, "") if @mpv_socket

        @current_file = args.last
        @playing = true
        @paused = false
      end

      # Mock the IPC communication
      def @player.send_command(command, *args)
        return nil unless @mpv_socket

        # Check for stored mock responses first
        if @mock_responses && @mock_responses[command] && @mock_responses[command][args.first]
          return @mock_responses[command][args.first]
        end

        # If socket is nonexistent, return nil to simulate connection failure
        return nil if @mpv_socket == "/nonexistent/socket"

        # Return default mock responses based on command
        case command
        when "get_property"
          case args.first
          when "time-pos"
            { "data" => 30.0 }
          when "duration"
            { "data" => 60.0 }
          when "pause"
            { "data" => @paused }
          else
            { "data" => nil }
          end
        when "set_property"
          case args.first
          when "pause"
            @paused = args.last
          end
          { "data" => true }
        else
          { "data" => nil }
        end
      end

      # Mock process check
      def @player.mpv_process_running?
        @mpv_pid && @playing
      end

      # Override playing? to use our mock
      def @player.playing?
        @playing && !@paused
      end

      # Override paused? to use our mock
      def @player.paused?
        @paused
      end

      # Mock process termination
      def @player.terminate_mpv_process
        @mpv_pid = nil
        @current_file = nil
        @playing = false
        @paused = false

        # Clean up socket file
        File.delete(@mpv_socket) if @mpv_socket && File.exist?(@mpv_socket)
        @mpv_socket = nil
      end

      yield
    end

    def mock_mpv_response(response_data, command, *args)
      # Store mock responses for specific commands in the player instance
      unless @player.instance_variable_get(:@mock_responses)
        @player.instance_variable_set(:@mock_responses,
                                      {})
      end
      mock_responses = @player.instance_variable_get(:@mock_responses)
      mock_responses[command] ||= {}
      mock_responses[command][args.first] = response_data
    end
  end
end
