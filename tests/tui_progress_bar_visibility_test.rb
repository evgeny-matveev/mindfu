# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/tui"

module MeditationPlayer
  class TUIProgressBarVisibilityTest < Test
    def setup
      @state = PlayerState.new(AudioPlayer.new)
      @tui = TUI.new(@state)

      # Mock curses window for testing
      @window = mock_window
      @tui.instance_variable_set(:@window, @window)
    end

    def test_progress_bar_shows_when_playing
      # When state is playing, progress bar should be drawn
      @state.stub(:playing?, true) do
        @state.stub(:paused?, false) do
          @state.player.stub(:current_progress, 0.5) do
            @tui.send(:draw_status)

            # Verify progress bar method was called
            progress_bar_calls = @window.calls.select do |call|
              call[:method] == :addstr && call[:args][0].include?("[")
            end
            assert_operator progress_bar_calls.length, :>, 0,
                            "Progress bar should be visible when playing"
          end
        end
      end
    end

    def test_progress_bar_shows_when_paused
      # When state is paused, progress bar should be drawn
      @state.stub(:playing?, false) do
        @state.stub(:paused?, true) do
          @state.player.stub(:current_progress, 0.7) do
            @tui.send(:draw_status)

            # Verify progress bar method was called
            progress_bar_calls = @window.calls.select do |call|
              call[:method] == :addstr && call[:args][0].include?("[")
            end
            assert_operator progress_bar_calls.length, :>, 0,
                            "Progress bar should be visible when paused"
          end
        end
      end
    end

    def test_progress_bar_hidden_when_stopped
      # When state is stopped, progress bar should not be drawn
      @state.stub(:playing?, false) do
        @state.stub(:paused?, false) do
          @tui.send(:draw_status)

          # Verify progress bar method was not called
          progress_bar_calls = @window.calls.select do |call|
            call[:method] == :addstr && call[:args][0].include?("[")
          end
          assert_equal 0, progress_bar_calls.length, "Progress bar should be hidden when stopped"
        end
      end
    end

    def test_progress_bar_positioned_correctly
      # Progress bar should be positioned at line 5, column 2
      @state.stub(:playing?, true) do
        @state.stub(:paused?, false) do
          @state.player.stub(:current_progress, 0.3) do
            @tui.send(:draw_status)

            # Check that progress bar is positioned at line 5, column 2
            progress_bar_call = @window.calls.find do |call|
              call[:method] == :setpos && call[:args] == [5, 2]
            end
            assert progress_bar_call, "Progress bar should be positioned at line 5, column 2"

            # Check that progress bar content follows positioning
            content_call = @window.calls.find do |call|
              call[:method] == :addstr && call[:args][0].include?("[")
            end
            assert content_call, "Progress bar content should be drawn after positioning"
          end
        end
      end
    end

    def test_progress_bar_shows_percentage
      # Progress bar should show percentage along with visual bar
      @state.stub(:playing?, true) do
        @state.stub(:paused?, false) do
          @state.player.stub(:current_progress, 0.75) do
            @tui.send(:draw_status)

            # Check that percentage is displayed
            percentage_call = @window.calls.find do |call|
              call[:method] == :addstr && call[:args][0].include?("75%")
            end
            assert percentage_call, "Progress bar should show 75% when progress is 0.75"
          end
        end
      end
    end

    def test_progress_bar_updates_during_playback
      # Progress bar should update with different progress values
      @state.stub(:playing?, true) do
        @state.stub(:paused?, false) do
          # Test with 25% progress
          @state.player.stub(:current_progress, 0.25) do
            @tui.send(:draw_status)

            call_twenty_five = @window.calls.find do |call|
              call[:method] == :addstr && call[:args][0].include?("[==")
            end
            assert call_twenty_five, "Progress bar should show 25% as [==        ]"
          end

          # Reset window calls
          @window.calls.clear

          # Test with 80% progress
          @state.player.stub(:current_progress, 0.8) do
            @tui.send(:draw_status)

            call_eighty = @window.calls.find do |call|
              call[:method] == :addstr && call[:args][0].include?("[========")
            end
            assert call_eighty, "Progress bar should show 80% as [========  ]"
          end
        end
      end
    end

    private

    def mock_window
      # Mock window that records all method calls
      mock = Object.new
      mock.instance_variable_set(:@calls, [])
      mock.define_singleton_method(:calls) { @calls }
      mock.define_singleton_method(:clear) { @calls = [] }
      mock.define_singleton_method(:method_missing) do |method, *args|
        @calls << { method: method, args: args }
        self
      end
      mock.define_singleton_method(:respond_to_missing?) { true }
      mock
    end
  end
end
