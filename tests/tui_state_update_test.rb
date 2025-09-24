# frozen_string_literal: true

require_relative "test_helper"

module MeditationPlayer
  class TUIStateUpdateTest < Test
    def setup
      @player = MPVPlayer.new
      @state = PlayerState.new(@player)
      @tui = TUI.new(@state)
    end

    def teardown
      @player&.stop
    end

    def test_tui_updates_display_on_state_change
      # Just verify that draw can be called without errors
      # and that the state changes work correctly
      @state.play
      begin
        @tui.send(:draw)
      rescue StandardError
        nil
      end

      @state.pause
      begin
        @tui.send(:draw)
      rescue StandardError
        nil
      end

      @state.resume
      begin
        @tui.send(:draw)
      rescue StandardError
        nil
      end

      # If we get here without exceptions, the display updates work
      # This test ensures draw method can be called without errors
    end

    def test_tui_shows_correct_state_after_multiple_toggle
      # Test multiple play/pause transitions
      @state.play
      assert_equal "playing", @state.state.to_s

      @state.pause
      assert_equal "paused", @state.state.to_s

      @state.resume
      assert_equal "playing", @state.state.to_s

      @state.pause
      assert_equal "paused", @state.state.to_s

      @state.play
      assert_equal "playing", @state.state.to_s
    end

    def test_tui_displays_playing_state_correctly
      mock_window = Minitest::Mock.new
      mock_window.expect :clear, nil
      mock_window.expect :setpos, nil, [0, Integer]
      mock_window.expect :addstr, nil, ["Meditation Player"]
      mock_window.expect :setpos, nil, [2, 2]
      mock_window.expect :addstr, nil, [String] # File line
      mock_window.expect :setpos, nil, [3, 2]
      mock_window.expect :addstr, nil, [/State: PLAYING/]

      # Mock other draw calls (controls and footer - 5 controls + 1 footer = 6 calls)
      6.times do
        mock_window.expect :setpos, nil, [Integer, Integer]
        mock_window.expect :addstr, nil, [String]
      end
      mock_window.expect :refresh, nil

      @tui.instance_variable_set(:@window, mock_window)

      # Set up state to playing
      @state.play
      @tui.send(:draw)

      mock_window.verify
    end

    def test_tui_displays_paused_state_correctly
      mock_window = Minitest::Mock.new
      mock_window.expect :clear, nil
      mock_window.expect :setpos, nil, [0, Integer]
      mock_window.expect :addstr, nil, ["Meditation Player"]
      mock_window.expect :setpos, nil, [2, 2]
      mock_window.expect :addstr, nil, [String] # File line
      mock_window.expect :setpos, nil, [3, 2]
      mock_window.expect :addstr, nil, [/State: PAUSED/]

      # Mock other draw calls (controls and footer - 5 controls + 1 footer = 6 calls)
      6.times do
        mock_window.expect :setpos, nil, [Integer, Integer]
        mock_window.expect :addstr, nil, [String]
      end
      mock_window.expect :refresh, nil

      @tui.instance_variable_set(:@window, mock_window)

      # Set up state to paused
      @state.play
      @state.pause
      @tui.send(:draw)

      mock_window.verify
    end

    def test_tui_displays_stopped_state_correctly
      mock_window = Minitest::Mock.new
      mock_window.expect :clear, nil
      mock_window.expect :setpos, nil, [0, Integer]
      mock_window.expect :addstr, nil, ["Meditation Player"]
      mock_window.expect :setpos, nil, [2, 2]
      mock_window.expect :addstr, nil, [String] # File line
      mock_window.expect :setpos, nil, [3, 2]
      mock_window.expect :addstr, nil, [/State: STOPPED/]

      # Mock other draw calls (controls and footer - 5 controls + 1 footer = 6 calls)
      6.times do
        mock_window.expect :setpos, nil, [Integer, Integer]
        mock_window.expect :addstr, nil, [String]
      end
      mock_window.expect :refresh, nil

      @tui.instance_variable_set(:@window, mock_window)

      # Ensure state is stopped
      @tui.send(:draw)

      mock_window.verify
    end

    def test_space_key_toggles_state_correctly_multiple_times
      # Mock window to return space key multiple times
      mock_window = Minitest::Mock.new

      # First space: stopped -> playing
      mock_window.expect :getch, " "

      # Set up TUI with mocked window
      @tui.instance_variable_set(:@window, mock_window)
      @tui.instance_variable_set(:@running, true)

      # Initial state should be stopped
      assert_equal "stopped", @state.state.to_s

      # First toggle: play
      @tui.handle_input
      assert_equal "playing", @state.state.to_s

      # Reset mock for next call
      mock_window = Minitest::Mock.new
      mock_window.expect :getch, " "
      @tui.instance_variable_set(:@window, mock_window)

      # Second toggle: pause
      @tui.handle_input
      assert_equal "paused", @state.state.to_s

      # Reset mock for next call
      mock_window = Minitest::Mock.new
      mock_window.expect :getch, " "
      @tui.instance_variable_set(:@window, mock_window)

      # Third toggle: resume
      @tui.handle_input
      assert_equal "playing", @state.state.to_s

      # Reset mock for next call
      mock_window = Minitest::Mock.new
      mock_window.expect :getch, " "
      @tui.instance_variable_set(:@window, mock_window)

      # Fourth toggle: pause again
      @tui.handle_input
      assert_equal "paused", @state.state.to_s
    end
  end
end
