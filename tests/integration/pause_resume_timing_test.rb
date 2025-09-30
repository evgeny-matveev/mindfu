# frozen_string_literal: true

require_relative "../test_helper"

module MeditationPlayer
  class PauseResumeTimingTest < Test
    def setup
      @player = MPVPlayer.new
      @state = PlayerState.new(@player)
    end

    def teardown
      @player&.stop
    end

    def test_pause_resume_basic_functionality
      mock_mpv_with_timing do
        # Setup player state directly
        @player.instance_variable_set(:@mpv_pid, 12_345)
        @player.instance_variable_set(:@mpv_socket, "/tmp/mpvsocket_test")
        @player.instance_variable_set(:@playing, true)
        @player.instance_variable_set(:@paused, false)

        @state.play

        # Pause
        @state.pause
        assert_predicate @state, :paused?
        assert_predicate @player, :paused?

        # Resume
        @state.resume
        assert_predicate @state, :playing?
        refute_predicate @player, :paused?
      end
    end

    def test_multiple_pause_resume_cycles
      mock_mpv_with_timing do
        # Setup player state directly
        @player.instance_variable_set(:@mpv_pid, 12_345)
        @player.instance_variable_set(:@mpv_socket, "/tmp/mpvsocket_test")
        @player.instance_variable_set(:@playing, true)
        @player.instance_variable_set(:@paused, false)

        @state.play

        # Test multiple pause/resume cycles
        @state.pause
        @state.resume
        assert_predicate @state, :playing?
        refute_predicate @player, :paused?

        @state.pause
        assert_predicate @state, :paused?
        assert_predicate @player, :paused?

        @state.resume
        assert_predicate @state, :playing?
      end
    end

    def test_pause_resume_final_player_state
      mock_mpv_with_timing do
        # Setup player state directly
        @player.instance_variable_set(:@mpv_pid, 12_345)
        @player.instance_variable_set(:@mpv_socket, "/tmp/mpvsocket_test")
        @player.instance_variable_set(:@playing, true)
        @player.instance_variable_set(:@paused, false)

        @state.play

        # Test multiple pause/resume cycles
        @state.pause
        @state.resume
        @state.pause
        @state.resume

        refute_predicate @player, :paused?
      end
    end

    private

    def mock_mpv_with_timing
      # Mock mpv process with timing capabilities
      def @player.spawn_mpv(*args)
        @mpv_pid = 12_345
        @mpv_socket = "/tmp/mpvsocket_test_#{object_id}"
        @current_file = args.last
        @playing = true
        @paused = false
        @current_position = 0.0
        @duration = 10.0 # Mock 10-second duration for easier calculations
      end

      def @player.send_command(command, *args)
        return nil unless @mpv_socket

        case command
        when "get_property"
          case args.first
          when "time-pos"
            { "data" => @current_position }
          when "duration"
            { "data" => @duration }
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

      def @player.mpv_process_running?
        @mpv_pid && @playing
      end

      def @player.playing?
        @playing && !@paused
      end

      def @player.paused?
        @paused
      end

      def @player.terminate_mpv_process
        @mpv_pid = nil
        @current_file = nil
        @playing = false
        @paused = false
      end

      yield
    end
  end
end
