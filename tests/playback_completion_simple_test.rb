# frozen_string_literal: true

require_relative "test_helper"

module MeditationPlayer
  class PlaybackCompletionSimpleTest < Test
    def setup
      @player = MPVPlayer.new
      @state = PlayerState.new(@player)
      @test_file = File.join(Dir.pwd, "low_bass_sine.mp3")
    end

    def teardown
      @player&.stop
    end

    def test_player_has_completion_callback_mechanism
      # Test that the MPVPlayer has the completion callback functionality
      assert_respond_to @player, :on_completion
      assert_respond_to @player, :check_completion
      assert_respond_to @player, :playback_completed?
    end

    def test_completion_callback_gets_called
      callback_called = false
      callback_progress = nil

      @player.on_completion do |progress|
        callback_called = true
        callback_progress = progress
      end

      # Simulate completion by calling the callback directly
      @player.instance_variable_get(:@completion_callback).call(0.95)

      assert callback_called
      assert_in_delta 0.95, callback_progress
    end

    def test_state_has_completion_handling
      # Test that PlayerState has completion handling methods (now public method)
      assert_respond_to @state, :check_completion
    end

    def test_completion_threshold_behavior
      # Test the 90% threshold logic in PlayerState
      # This simulates the behavior when playback completes naturally

      # Test with 95% progress (should update history)
      @state.send(:handle_natural_completion, 0.95)
      # The method should not raise an error

      # Test with 85% progress (should not update history)
      @state.send(:handle_natural_completion, 0.85)
      # The method should not raise an error

      # Test with exactly 90% progress (should update history)
      @state.send(:handle_natural_completion, 0.90)
      # The method should not raise an error
    end

    def test_player_progress_tracking
      # Test that MPVPlayer can track progress
      assert_respond_to @player, :current_progress

      # Test that progress is between 0 and 1
      progress = @player.current_progress
      assert_operator progress, :>=, 0.0
      assert_operator progress, :<=, 1.0
    end

    def test_completion_detection_logic
      # Test the completion detection logic with a fresh player
      fresh_player = MPVPlayer.new

      refute_predicate fresh_player, :playback_completed?

      # Set up a mock playing state
      fresh_player.instance_variable_set(:@playing, true)
      fresh_player.instance_variable_set(:@mpv_pid, 12_345)

      # Still not completed because process is running
      refute_predicate fresh_player, :playback_completed?

      # Simulate process termination
      def fresh_player.process_running?(_pid)
        false
      end

      # Now should be completed
      assert_predicate fresh_player, :playback_completed?
    end

    def test_random_file_selector_history_tracking
      # Test that RandomFileSelector can track played files
      assert_respond_to @state.random_selector, :record_played_file

      # Mock the player to include our test file
      @player.stub(:audio_files, [@test_file]) do
        # Test recording a file
        @state.random_selector.record_played_file(@test_file)

        # Verify it was recorded
        recently_played = @state.random_selector.instance_variable_get(:@recently_played_files)
        assert_includes recently_played, File.basename(@test_file)
      end
    end
  end
end
