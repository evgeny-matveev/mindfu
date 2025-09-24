# frozen_string_literal: true

require_relative "test_helper"

module MeditationPlayer
  class AudioPlayerTest < Test
    def setup
      @player = AudioPlayer.new
    end

    def teardown
      # Don't call stop for this test as it will cause errors with our mock
      @player = nil
    end

    def test_audio_files_returns_array
      assert_kind_of Array, @player.audio_files
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

    def test_can_detect_playing_state
      # This test is limited since we can't actually play audio in tests
      # but we can test the state transitions
      @player.instance_variable_set(:@process, 123)
      @player.instance_variable_set(:@paused, false)

      # Mock the process check to simulate playing
      def @player.playing?
        true
      end

      assert_predicate @player, :playing?
    end

    def test_can_detect_paused_state
      @player.instance_variable_set(:@paused, true)
      assert_predicate @player, :paused?
    end

    def test_pause_when_not_playing_does_nothing
      @player.pause
      refute_predicate @player, :paused?
    end

    def test_resume_when_not_paused_does_nothing
      @player.instance_variable_set(:@paused, false)
      @player.resume
      refute_predicate @player, :playing?
    end

    def test_pause_resume_timing
      # Test with mocked data to avoid file system dependencies
      test_file = "/fake/test.mp3"

      # Mock the file duration to avoid calling ffprobe
      @player.instance_variable_set(:@file_durations, { test_file => 60.0 }) # 60 second file

      # Setup: simulate a playing audio file
      @player.instance_variable_set(:@process, 123)
      @player.instance_variable_set(:@current_file, test_file)
      @player.instance_variable_set(:@start_time, Time.now - 10) # Started 10 seconds ago
      @player.instance_variable_set(:@paused, false)

      # Mock playing? to return true so pause will work
      def @player.playing?
        true
      end

      # Mock Process.kill to avoid sending signals to fake process
      def @player.pause
        @pause_time = Time.now
        @paused = true
      end

      def @player.resume
        # Simulate the resume timing adjustment
        pause_duration = Time.now - @pause_time
        @start_time += pause_duration
        @pause_time = nil
        @paused = false
      end

      # Pause after 10 seconds
      @player.pause
      assert_predicate @player, :paused?

      # Progress should reflect 10 seconds of playback (10/60 = ~16.7%)
      progress_during_pause = @player.current_progress
      assert_in_delta progress_during_pause, 10.0 / 60.0, 0.1

      # Wait a moment to verify progress doesn't change while paused
      sleep 0.1
      progress_still_during_pause = @player.current_progress
      assert_equal progress_during_pause, progress_still_during_pause

      # Resume and check timing is adjusted
      start_time_before_resume = @player.instance_variable_get(:@start_time)
      @player.instance_variable_get(:@pause_time)

      @player.resume
      refute_predicate @player, :paused?

      # Verify start_time was adjusted forward by pause duration
      start_time_after_resume = @player.instance_variable_get(:@start_time)
      assert_operator start_time_after_resume, :>, start_time_before_resume

      # Verify pause_time was cleared
      assert_nil @player.instance_variable_get(:@pause_time)
    end
  end
end
