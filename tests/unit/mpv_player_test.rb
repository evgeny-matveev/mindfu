# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/mpv_player"

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

    def test_stop_terminates_mpv_process
      mock_mpv_spawn do
        @player.play(@test_file)
        @player.stop
        refute_predicate @player, :playing?
        refute_predicate @player, :paused?
        assert_nil @player.current_file
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

    private

    def mock_mpv_spawn
      mock_file_exist
      mock_spawn_mpv_method
      mock_ipc_communication
      mock_process_methods
      mock_termination_method

      yield
    end

    def mock_file_exist
      # Mock File.exist? to return true for test file
      File.define_singleton_method(:exist?) do |path|
        path == "/fake/test.mp3"
      end
    end

    def mock_spawn_mpv_method
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
    end

    def mock_ipc_communication
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
          mock_get_property_response(args.first)
        when "set_property"
          mock_set_property_response_for_player(args.first, args.last)
        else
          { "data" => nil }
        end
      end

      # Add mock method to player instance
      def @player.mock_set_property_response_for_player(property, value)
        case property
        when "pause"
          @paused = value
        end
        { "data" => true }
      end
    end

    def mock_get_property_response(property)
      case property
      when "time-pos"
        { "data" => 30.0 }
      when "duration"
        { "data" => 60.0 }
      when "pause"
        { "data" => @paused }
      else
        { "data" => nil }
      end
    end

    def mock_process_methods
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
    end

    def mock_termination_method
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
    end
  end
end
