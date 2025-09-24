# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/audio_player"
require_relative "../lib/player_state"
require_relative "../lib/tui"

module MeditationPlayer
  class ProgressTrackingSyncTest < Test
    def setup
      @player = AudioPlayer.new
      @state = PlayerState.new(@player)
      @tui = TUI.new(@state)
    end

    def teardown
      @player.stop
    end

    def test_progress_bar_shows_90_percent_threshold
      # Test that progress bar correctly shows the 90% threshold used for marking files as completed
      mock_files = ["test.mp3"]
      @player.stub(:audio_files, mock_files) do
        # Test at 89% (should NOT be marked as completed)
        @player.stub(:current_progress, 0.89) do
          progress_bar = @tui.send(:format_progress_bar, 0.89)
          assert_equal "[========  ]", progress_bar
          assert_equal 8, progress_bar.count("=")
        end

        # Test at 90% (should be marked as completed)
        @player.stub(:current_progress, 0.90) do
          progress_bar = @tui.send(:format_progress_bar, 0.90)
          assert_equal "[==========]", progress_bar
          assert_equal 10, progress_bar.count("=")
        end

        # Test at 95% (should be marked as completed)
        @player.stub(:current_progress, 0.95) do
          progress_bar = @tui.send(:format_progress_bar, 0.95)
          assert_equal "[==========]", progress_bar
          assert_equal 10, progress_bar.count("=")
        end
      end
    end

    def test_progress_bar_uses_same_calculation_as_completion_logic
      # Test that progress bar uses the same progress calculation as the completion logic
      mock_files = ["test.mp3"]
      @player.stub(:audio_files, mock_files) do
        # Simulate a scenario where progress is calculated
        @player.instance_variable_set(:@current_file, "test.mp3")
        @player.instance_variable_set(:@start_time, Time.now - 30) # 30 seconds ago

        # Mock a 60-second file
        @player.stub(:get_file_duration, 60.0) do
          # Both should use the same calculation
          progress_bar_progress = @player.current_progress
          completion_progress = @player.send(:calculate_progress)

          assert_in_delta progress_bar_progress, completion_progress, 0.001,
                          "Progress bar and completion logic should use same calculation"
        end
      end
    end

    def test_progress_bar_updates_during_playback_simulation
      # Test that progress bar would update correctly during playback
      mock_files = ["test.mp3"]
      @player.stub(:audio_files, mock_files) do
        @player.instance_variable_set(:@current_file, "test.mp3")
        @player.instance_variable_set(:@start_time, Time.now)

        # Mock a 120-second file
        @player.stub(:get_file_duration, 120.0) do
          # Simulate progress at different time points
          progress_points = [0.0, 0.25, 0.5, 0.75, 0.89, 0.90, 0.95, 1.0]

          progress_points.each do |expected_progress|
            @player.instance_variable_set(:@start_time, Time.now - (expected_progress * 120))

            actual_progress = @player.current_progress
            progress_bar = @tui.send(:format_progress_bar, actual_progress)

            # Verify progress bar shows correct visual representation
            expected_filled = if expected_progress >= 0.9
                                10 # Full bar at 90% threshold
                              else
                                (expected_progress * 10).floor
                              end
            actual_filled = progress_bar.count("=")

            assert_equal expected_filled, actual_filled,
                         "Progress bar should show #{expected_progress} as #{expected_filled}/10 filled segments"
          end
        end
      end
    end

    def test_progress_bar_consistency_with_90_percent_rule
      # Test that the visual representation aligns with the 90% completion rule
      mock_files = ["test.mp3"]
      @player.stub(:audio_files, mock_files) do
        # Test the boundary around 90%
        below_threshold = 0.89
        at_threshold = 0.90
        above_threshold = 0.91

        # Below threshold should show 89% visually
        below_bar = @tui.send(:format_progress_bar, below_threshold)
        below_percentage = (below_threshold * 100).round

        # At threshold should show 90% visually
        at_bar = @tui.send(:format_progress_bar, at_threshold)
        at_percentage = (at_threshold * 100).round

        # Above threshold should show 91% visually
        above_bar = @tui.send(:format_progress_bar, above_threshold)
        above_percentage = (above_threshold * 100).round

        # Verify visual representation matches completion logic
        assert_operator below_percentage, :<, 90, "89% should be below 90% threshold"
        assert_operator at_percentage, :>=, 90, "90% should meet threshold"
        assert_operator above_percentage, :>=, 90, "91% should exceed threshold"

        # Verify progress bar shows the distinction
        assert_operator below_bar.count("="), :<, 10, "89% should not show full progress bar"
        assert_equal 10, at_bar.count("="), "90% should show full progress bar"
        assert_equal 10, above_bar.count("="), "91% should show full progress bar"
      end
    end
  end
end
