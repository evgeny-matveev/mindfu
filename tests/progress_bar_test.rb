# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/tui"

module MeditationPlayer
  class ProgressBarTest < Test
    def setup
      @state = PlayerState.new(MPVPlayer.new)
      @tui = TUI.new(@state)
    end

    def test_progress_bar_format_0_percent
      bar = format_progress_bar(0.0)
      assert_equal "[          ]", bar
    end

    def test_progress_bar_format_10_percent
      bar = format_progress_bar(0.1)
      assert_equal "[=         ]", bar
    end

    def test_progress_bar_format_50_percent
      bar = format_progress_bar(0.5)
      assert_equal "[=====     ]", bar
    end

    def test_progress_bar_format_100_percent
      bar = format_progress_bar(1.0)
      assert_equal "[==========]", bar
    end

    def test_progress_bar_rounding_down
      bar = format_progress_bar(0.04) # 4% should round to 0%
      assert_equal "[          ]", bar
    end

    def test_progress_bar_rounding_up
      bar = format_progress_bar(0.96) # 96% should round to 100%
      assert_equal "[==========]", bar
    end

    def test_progress_bar_handles_progress_above_one
      bar = format_progress_bar(1.5) # Above 100% should cap at 100%
      assert_equal "[==========]", bar
    end

    def test_progress_bar_handles_negative_progress
      bar = format_progress_bar(-0.1) # Negative should show 0%
      assert_equal "[          ]", bar
    end

    def test_progress_bar_updates_with_actual_tracking
      mock_files = ["test.mp3"]
      @state.player.stub(:audio_files, mock_files) do
        @state.player.stub(:current_progress, 0.3) do
          @state.player.instance_variable_set(:@current_file, "test.mp3")

          # Should show 30% progress
          assert_equal "[===       ]", format_progress_bar(@state.player.current_progress)
        end
      end
    end

    private

    # Call the actual TUI method for formatting progress bar
    def format_progress_bar(progress)
      @tui.send(:format_progress_bar, progress)
    end
  end
end
