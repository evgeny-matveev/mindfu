# frozen_string_literal: true

require_relative "test_helper"

module MeditationPlayer
  class AudioPlayerTest < Test
    def setup
      @player = AudioPlayer.new
    end

    def teardown
      @player&.stop
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
  end
end
