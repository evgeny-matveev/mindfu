# frozen_string_literal: true

require_relative "test_helper"

module MeditationPlayer
  class TUIProgressBarTest < Test
    def setup
      @player = MPVPlayer.new
      @state = PlayerState.new(@player)
      @tui = TUI.new(@state)

      # Mock curses to avoid actual terminal manipulation
      @mock_window = Minitest::Mock.new
      @tui.instance_variable_set(:@window, @mock_window)
    end

    def teardown
      @player&.stop
    end

    def test_progress_bar_should_be_displayed
      # Progress bar has been restored and should be displayed
      # The draw method should call draw_progress_bar

      # Track if draw_progress_bar is called
      progress_bar_called = false
      @tui.define_singleton_method(:draw_progress_bar) do
        progress_bar_called = true
      end

      # Mock the window to avoid actual curses operations
      @mock_window.expect :clear, nil
      @mock_window.expect :setpos, nil, [Integer, Integer]
      @mock_window.expect :addstr, nil, [String]
      @mock_window.expect :refresh, nil

      # Allow any other calls
      def @mock_window.method_missing(*args); end

      # Call private draw method for testing
      @tui.send(:draw)

      # Verify progress bar method was called
      assert progress_bar_called, "draw_progress_bar should be called"
    end

    def test_draw_progress_bar_method_should_be_private
      # The method should be private for backward compatibility
      assert_includes @tui.private_methods, :draw_progress_bar,
                      "draw_progress_bar should be private"
    end
  end
end
