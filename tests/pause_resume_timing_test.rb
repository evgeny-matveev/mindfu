# frozen_string_literal: true

require_relative "test_helper"

module MeditationPlayer
  class PauseResumeTimingTest < Test
    def setup
      @player = MPVPlayer.new
      @state = PlayerState.new(@player)
    end

    def teardown
      @player&.stop
    end

    def test_pause_resume_maintains_correct_timing
      mock_mpv_with_timing do
        # Setup player state directly
        @player.instance_variable_set(:@mpv_pid, 12_345)
        @player.instance_variable_set(:@mpv_socket, "/tmp/mpvsocket_test")
        @player.instance_variable_set(:@playing, true)
        @player.instance_variable_set(:@paused, false)
        @player.instance_variable_set(:@current_position, 0.0)
        @player.instance_variable_set(:@duration, 10.0)

        @state.play

        # Simulate progress after playing
        @player.instance_variable_set(:@current_position, 2.0)
        progress_before_pause = @player.current_progress
        assert_operator progress_before_pause, :>, 0.0
        assert_operator progress_before_pause, :<, 1.0

        # Pause
        @state.pause
        assert_predicate @state, :paused?
        assert_predicate @player, :paused?

        # Simulate waiting - progress should not change
        progress_during_pause = @player.current_progress
        assert_in_delta progress_before_pause, progress_during_pause, 0.01

        # Resume
        @state.resume
        assert_predicate @state, :playing?
        refute_predicate @player, :paused?

        # Simulate progress after resume
        @player.instance_variable_set(:@current_position, 3.0)
        progress_after_resume = @player.current_progress
        assert_operator progress_after_resume, :>, progress_during_pause
      end
    end

    def test_multiple_pause_resume_cycles
      mock_mpv_with_timing do
        # Setup player state directly
        @player.instance_variable_set(:@mpv_pid, 12_345)
        @player.instance_variable_set(:@mpv_socket, "/tmp/mpvsocket_test")
        @player.instance_variable_set(:@playing, true)
        @player.instance_variable_set(:@paused, false)
        @player.instance_variable_set(:@current_position, 0.0)
        @player.instance_variable_set(:@duration, 10.0)

        @state.play

        # Simulate progress at different stages
        @player.instance_variable_set(:@current_position, 1.0)
        progress_one = @player.current_progress

        @state.pause
        @state.resume
        @player.instance_variable_set(:@current_position, 2.0)

        @state.pause
        progress_two = @player.current_progress

        @state.resume
        @player.instance_variable_set(:@current_position, 3.0)
        progress_three = @player.current_progress

        # Progress should have increased between cycles
        assert_operator progress_three, :>, progress_two
        assert_operator progress_two, :>, progress_one
      end
    end

    def test_resume_after_long_pause_starts_from_correct_position
      mock_mpv_with_timing do
        # Setup player state directly
        @player.instance_variable_set(:@mpv_pid, 12_345)
        @player.instance_variable_set(:@mpv_socket, "/tmp/mpvsocket_test")
        @player.instance_variable_set(:@playing, true)
        @player.instance_variable_set(:@paused, false)
        @player.instance_variable_set(:@current_position, 0.0)
        @player.instance_variable_set(:@duration, 10.0)

        @state.play

        # Simulate playing for 2 seconds
        @player.instance_variable_set(:@current_position, 2.0)

        # Pause
        @state.pause
        progress_at_pause = @player.current_progress
        assert_operator progress_at_pause, :>, 0.0

        # Progress should still be the same after simulated waiting
        progress_after_long_pause = @player.current_progress
        assert_in_delta progress_at_pause, progress_after_long_pause, 0.01

        # Resume and simulate more progress
        @state.resume
        @player.instance_variable_set(:@current_position, 2.3)
        progress_after_resume = @player.current_progress
        assert_operator progress_after_resume, :>, progress_after_long_pause
      end
    end

    def test_mpv_player_timing_calculation
      mock_mpv_with_timing do
        # Setup player state directly
        @player.instance_variable_set(:@mpv_pid, 12_345)
        @player.instance_variable_set(:@mpv_socket, "/tmp/mpvsocket_test")
        @player.instance_variable_set(:@playing, true)
        @player.instance_variable_set(:@paused, false)
        @player.instance_variable_set(:@current_position, 0.0)
        @player.instance_variable_set(:@duration, 5.0) # 5 second file for this test

        @player.play("/fake/test.mp3")

        # Simulate play for 1 second
        @player.instance_variable_set(:@current_position, 1.0)
        progress_after_1s = @player.current_progress
        assert_operator progress_after_1s, :>, 0.18 # ~1/5 = 0.2, allow some tolerance

        # Pause
        @player.pause
        progress_during_pause = @player.current_progress
        assert_in_delta progress_after_1s, progress_during_pause, 0.01

        # Resume and simulate more progress
        @player.resume
        @player.instance_variable_set(:@current_position, 2.0)
        progress_after_resume = @player.current_progress
        assert_operator progress_after_resume, :>, progress_during_pause
      end
    end

    def test_start_time_adjustment_on_resume
      # Test that pause/resume state works correctly
      mock_mpv_with_timing do
        # Setup player state directly
        @player.instance_variable_set(:@mpv_pid, 12_345)
        @player.instance_variable_set(:@mpv_socket, "/tmp/mpvsocket_test")
        @player.instance_variable_set(:@playing, true)
        @player.instance_variable_set(:@paused, false)
        @player.instance_variable_set(:@current_position, 0.0)
        @player.instance_variable_set(:@duration, 10.0)

        @player.play("/fake/test.mp3")

        # Play briefly
        @player.instance_variable_set(:@current_position, 0.3)

        @player.pause
        assert_predicate @player, :paused?

        # Wait a bit
        @player.instance_variable_set(:@current_position, 0.8)

        @player.resume
        refute_predicate @player, :paused?

        # Progress should continue after resume
        @player.instance_variable_set(:@current_position, 1.0)
        progress_after_resume = @player.current_progress
        assert_operator progress_after_resume, :>, 0.0
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
