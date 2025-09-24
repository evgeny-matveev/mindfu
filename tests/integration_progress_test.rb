# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/audio_player"
require_relative "../lib/player_state"

module MeditationPlayer
  class IntegrationProgressTest < Test
    def setup
      @player = AudioPlayer.new
      @state = PlayerState.new(@player)
    end

    def teardown
      @player.stop
    end

    def test_short_playback_does_not_mark_as_completed
      # Test that playing less than 90% doesn't mark file as completed
      mock_files = ["file1.mp3", "file2.mp3", "file3.mp3"]
      @player.stub(:audio_files, mock_files) do
        # Clear recently played files for this test
        @state.random_selector.instance_variable_set(:@recently_played_files, [])

        @player.stub(:current_progress, 0.3) do # 30% progress
          @state.play
          @state.stop

          # Should not be in recently played files
          recently_played = @state.random_selector.instance_variable_get(:@recently_played_files)
          refute_includes recently_played, "file1.mp3"
        end
      end
    end

    def test_almost_complete_playback_marks_as_completed
      # Test that playing 90%+ marks file as completed
      mock_files = ["file1.mp3", "file2.mp3", "file3.mp3"]
      @player.stub(:audio_files, mock_files) do
        # Clear recently played files for this test
        @state.random_selector.instance_variable_set(:@recently_played_files, [])

        # Set up current file and progress
        @player.instance_variable_set(:@current_file, "file1.mp3")
        @player.stub(:stop, 0.95) do # 95% progress
          @state.play
          @state.stop

          # Should be in recently played files
          recently_played = @state.random_selector.instance_variable_get(:@recently_played_files)
          assert_includes recently_played, "file1.mp3"
        end
      end
    end

    def test_next_track_marks_completed_if_progress_sufficient
      # Test that going to next track marks file as completed if 90%+ played
      mock_files = ["file1.mp3", "file2.mp3", "file3.mp3"]
      @player.stub(:audio_files, mock_files) do
        # Clear recently played files for this test
        @state.random_selector.instance_variable_set(:@recently_played_files, [])

        # Set up current file and progress
        @player.instance_variable_set(:@current_file, "file1.mp3")
        @player.stub(:stop, 0.92) do # 92% progress
          @state.play
          @state.next

          # Should be in recently played files
          recently_played = @state.random_selector.instance_variable_get(:@recently_played_files)
          assert_includes recently_played, "file1.mp3"
        end
      end
    end

    def test_next_track_does_not_mark_completed_if_progress_insufficient
      # Test that going to next track does NOT mark file if less than 90% played
      mock_files = ["file1.mp3", "file2.mp3", "file3.mp3"]
      @player.stub(:audio_files, mock_files) do
        # Clear recently played files for this test
        @state.random_selector.instance_variable_set(:@recently_played_files, [])

        @player.stub(:stop, 0.45) do # 45% progress
          @state.play
          @state.next

          # Should NOT be in recently played files
          recently_played = @state.random_selector.instance_variable_get(:@recently_played_files)
          refute_includes recently_played, "file1.mp3"
        end
      end
    end

    def test_excludes_completed_files_from_random_selection
      # Test that completed files are excluded from random selection
      mock_files = ["file1.mp3", "file2.mp3", "file3.mp3", "file4.mp3"]
      @player.stub(:audio_files, mock_files) do
        # Clear recently played files for this test
        @state.random_selector.instance_variable_set(:@recently_played_files, [])

        # Mark file1.mp3 as completed
        @state.random_selector.record_played_file("file1.mp3")

        # Should prefer other files
        selected = @state.random_selector.select_random_file
        refute_equal "file1.mp3", selected
      end
    end

    def test_ten_file_limit_enforced
      # Test that only 10 files can be marked as recently played
      mock_files = (1..20).map { |i| "file#{i}.mp3" }
      @player.stub(:audio_files, mock_files) do
        # Mark 12 files as completed
        12.times do |i|
          @state.random_selector.record_played_file("file#{i + 1}.mp3")
        end

        recently_played = @state.random_selector.instance_variable_get(:@recently_played_files)
        assert_equal 10, recently_played.length

        # Should contain the most recent 10 files (files 3-12)
        (3..12).each do |i|
          assert_includes recently_played, "file#{i}.mp3",
                          "Should include recent file: file#{i}.mp3"
        end

        # Should NOT contain the oldest files (files 1-2)
        refute_includes recently_played, "file1.mp3", "Should not include oldest file"
        refute_includes recently_played, "file2.mp3", "Should not include second oldest file"
      end
    end
  end
end
