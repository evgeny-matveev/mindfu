# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/audio_player"

module MeditationPlayer
  class AudioPlayerProgressTest < Test
    def setup
      @player = AudioPlayer.new
      @test_file = audio_files.first
    end

    def teardown
      @player.stop
    end

    def audio_files
      # Use a real audio file for testing
      Dir.glob(File.join(AudioPlayer::AUDIO_DIR, "*.{mp3,mp4,wav,ogg}"))
    end

    def test_tracks_playback_start_time
      skip "Needs actual audio file" if audio_files.empty?

      @player.play(@test_file)
      assert @player.instance_variable_get(:@start_time)
      assert_kind_of Time, @player.instance_variable_get(:@start_time)
    end

    def test_calculates_progress_during_playback
      skip "Needs actual audio file" if audio_files.empty?

      @player.play(@test_file)
      sleep 0.1  # Let it play briefly

      progress = @player.current_progress
      assert progress
      assert_operator progress, :>, 0.0
      assert_operator progress, :<=, 1.0
    end

    def test_stop_returns_progress_percentage
      skip "Needs actual audio file" if audio_files.empty?

      @player.play(@test_file)
      sleep 0.1  # Let it play briefly

      progress = @player.stop
      assert_kind_of Float, progress
      assert_operator progress, :>=, 0.0
      assert_operator progress, :<=, 1.0
    end

    def test_gets_file_duration
      skip "Needs actual audio file" if audio_files.empty?

      duration = @player.send(:get_file_duration, @test_file)
      assert_operator duration, :>, 0.0
      assert_kind_of Float, duration
    end

    def test_progress_capped_at_100_percent
      skip "Needs actual audio file" if audio_files.empty?

      # Mock a very long elapsed time
      @player.instance_variable_set(:@start_time, Time.now - 10_000)
      @player.instance_variable_set(:@current_file, @test_file)

      progress = @player.send(:calculate_progress)
      assert_in_delta(1.0, progress)
    end

    def test_handles_paused_progress_calculation
      skip "Needs actual audio file" if audio_files.empty?

      @player.play(@test_file)
      sleep 0.1
      @player.pause

      # Progress should be calculated based on pause time
      progress = @player.current_progress
      assert progress
      assert_operator progress, :>, 0.0
      assert_operator progress, :<=, 1.0
    end

    def test_resume_adjusts_start_time
      skip "Needs actual audio file" if audio_files.empty?

      @player.play(@test_file)
      sleep 0.1
      original_start_time = @player.instance_variable_get(:@start_time)
      @player.pause
      sleep 0.1
      @player.resume

      # Start time should be adjusted to account for pause
      new_start_time = @player.instance_variable_get(:@start_time)
      assert_operator new_start_time, :>, original_start_time
    end
  end
end
