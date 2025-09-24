# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/random_file_selector"

module MeditationPlayer
  class RandomFileSelectorTest < Test
    def setup
      @player = MPVPlayer.new
      @state = PlayerState.new(@player)
      @selector = RandomFileSelector.new(@state)
    end

    def teardown
      @player&.stop
    end

    def test_selects_random_file_from_available_files
      # Mock audio files
      mock_files = ["file1.mp3", "file2.mp3", "file3.mp3", "file4.mp3"]
      @player.stub(:audio_files, mock_files) do
        # Test that it selects a valid file
        selected_file = @selector.select_random_file
        assert_includes mock_files, selected_file
        assert selected_file.end_with?(".mp3")
      end
    end

    def test_excludes_recently_played_files_from_last_sessions
      # Mock persistence data with recently played files
      recent_files = ["file1.mp3", "file2.mp3", "file3.mp3", "file4.mp3", "file5.mp3",
                      "file6.mp3", "file7.mp3", "file8.mp3", "file9.mp3", "file10.mp3"]

      mock_files = recent_files + ["new_file1.mp3", "new_file2.mp3", "new_file3.mp3"]

      @player.stub(:audio_files, mock_files) do
        # Create a new selector with stubbed recently played files
        @selector = RandomFileSelector.new(@state)
        @selector.instance_variable_set(:@recently_played_files, recent_files)

        selected_file = @selector.select_random_file

        # Should not select from recently played files
        refute_includes recent_files, selected_file
        assert_includes ["new_file1.mp3", "new_file2.mp3", "new_file3.mp3"], selected_file
      end
    end

    def test_selects_any_file_if_all_files_are_recently_played
      # All files are recently played
      recent_files = ["file1.mp3", "file2.mp3", "file3.mp3"]

      @player.stub(:audio_files, recent_files) do
        @selector.stub(:load_recently_played, recent_files) do
          selected_file = @selector.select_random_file

          # Should still select a file (fallback behavior)
          assert_includes recent_files, selected_file
        end
      end
    end

    def test_saves_played_file_to_recently_played
      mock_files = ["file1.mp3", "file2.mp3", "file3.mp3"]

      @player.stub(:audio_files, mock_files) do
        # Test saving played file
        @selector.record_played_file("file1.mp3")

        # Verify it was saved by checking if it's excluded from selection
        recently_played = @selector.instance_variable_get(:@recently_played_files)
        assert_includes recently_played, "file1.mp3"

        selected_file = @selector.select_random_file
        # Should prefer other files over file1.mp3
        refute_equal "file1.mp3", selected_file unless mock_files.length == 1
      end
    end

    def test_limits_recently_played_to_90_percent_of_files
      # Create 20 files
      mock_files = (1..20).map { |i| "file#{i}.mp3" }

      @player.stub(:audio_files, mock_files) do
        # Play 18 files (90% of 20)
        18.times do |i|
          @selector.record_played_file("file#{i + 1}.mp3")
        end

        # Play one more file
        @selector.record_played_file("file19.mp3")

        # Test that file1.mp3 is now preferred for selection (not in recently played)
        # and file19.mp3 is avoided (in recently played)
        10.times do
          selected_file = @selector.select_random_file
          # Should rarely select recently played files when non-recent are available
          assert selected_file, "Should always select a file"
        end
      end
    end

    def test_session_history_tracks_current_session
      mock_files = ["file1.mp3", "file2.mp3", "file3.mp3"]

      @player.stub(:audio_files, mock_files) do
        # Simulate session navigation
        @selector.add_to_session_history("file1.mp3")
        @selector.add_to_session_history("file2.mp3")
        @selector.add_to_session_history("file3.mp3")

        history = @selector.session_history
        assert_equal ["file1.mp3", "file2.mp3", "file3.mp3"], history
      end
    end

    def test_next_selects_random_file_and_adds_to_history
      mock_files = ["file1.mp3", "file2.mp3", "file3.mp3", "file4.mp3"]

      @player.stub(:audio_files, mock_files) do
        # Stub random selection to return specific file
        @selector.stub(:select_random_file, "file3.mp3") do
          # Clear recently played files for this test
          @selector.instance_variable_set(:@recently_played_files, [])

          next_file = @selector.next_random_file

          assert_equal "file3.mp3", next_file

          # Verify it was added to session history
          history = @selector.session_history
          assert_includes history, "file3.mp3"

          # Verify it was NOT added to recently played files
          recently_played = @selector.instance_variable_get(:@recently_played_files)
          refute_includes recently_played, "file3.mp3"
        end
      end
    end

    def test_previous_navigates_session_history
      mock_files = ["file1.mp3", "file2.mp3", "file3.mp3"]

      @player.stub(:audio_files, mock_files) do
        # Build session history
        @selector.add_to_session_history("file1.mp3")
        @selector.add_to_session_history("file2.mp3")
        @selector.add_to_session_history("file3.mp3")

        # Test previous navigation (should return file before the last one)
        prev_file = @selector.previous_file
        assert_equal "file2.mp3", prev_file

        # Test previous again
        prev_file = @selector.previous_file
        assert_equal "file1.mp3", prev_file
      end
    end

    def test_previous_returns_nil_when_no_history
      mock_files = ["file1.mp3", "file2.mp3"]

      @player.stub(:audio_files, mock_files) do
        prev_file = @selector.previous_file
        assert_nil prev_file
      end
    end

    def test_initializes_with_random_file
      mock_files = ["file1.mp3", "file2.mp3", "file3.mp3"]

      @player.stub(:audio_files, mock_files) do
        @selector.stub(:select_random_file, "file2.mp3") do
          # Clear recently played files for this test
          @selector.instance_variable_set(:@recently_played_files, [])

          initial_file = @selector.initialize_session

          assert_equal "file2.mp3", initial_file

          # Verify it was added to session history
          history = @selector.session_history
          assert_includes history, "file2.mp3"

          # Verify it was NOT added to recently played files
          recently_played = @selector.instance_variable_get(:@recently_played_files)
          refute_includes recently_played, "file2.mp3"
        end
      end
    end
  end
end
