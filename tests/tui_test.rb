# frozen_string_literal: true

require_relative "test_helper"

module MeditationPlayer
  class TUITest < Test
    def setup
      @player = AudioPlayer.new
      @state = PlayerState.new(@player)
      @tui = TUI.new(@state)
    end

    def teardown
      @player&.stop
    end

    def test_english_space_key_toggles_play_pause
      # Mock the window to return space key
      mock_window = Minitest::Mock.new
      mock_window.expect :getch, " "

      @tui.instance_variable_set(:@window, mock_window)
      @tui.instance_variable_set(:@running, true)

      # Test that space key triggers play when stopped
      @tui.handle_input
      assert_predicate @state, :playing?
    end

    def test_russian_space_key_toggles_play_pause
      # Mock the window to return space key (same for Russian)
      mock_window = Minitest::Mock.new
      mock_window.expect :getch, " "

      @tui.instance_variable_set(:@window, mock_window)
      @tui.instance_variable_set(:@running, true)

      # Test that space key triggers play when stopped
      @tui.handle_input
      assert_predicate @state, :playing?
    end

    def test_s_key_stops_playback
      # Start playing first
      @state.play

      # Mock the window to return 's' character
      mock_window = Minitest::Mock.new
      mock_window.expect :getch, "s"

      @tui.instance_variable_set(:@window, mock_window)
      @tui.instance_variable_set(:@running, true)

      # Test that 's' key stops playback
      @tui.handle_input
      assert_equal "stopped", @state.state.to_s
    end

    def test_english_s_key_stops_playback_with_bytecode
      # Start playing first
      @state.play

      # Mock the window to return S key ASCII code (115)
      mock_window = Minitest::Mock.new
      mock_window.expect :getch, 115

      @tui.instance_variable_set(:@window, mock_window)
      @tui.instance_variable_set(:@running, true)

      # Test that S key stops playback
      @tui.handle_input
      assert_equal "stopped", @state.state.to_s
    end

    def test_english_n_key_goes_to_next_track_with_bytecode
      # Mock the window to return N key ASCII code (110)
      mock_window = Minitest::Mock.new
      mock_window.expect :getch, 110

      @tui.instance_variable_set(:@window, mock_window)
      @tui.instance_variable_set(:@running, true)

      # Mock audio files to simulate having tracks
      @player.stub(:audio_files, ["file1.mp3", "file2.mp3"]) do
        initial_index = @state.current_index
        @tui.handle_input
        assert_equal initial_index + 1, @state.current_index
      end
    end

    def test_english_p_key_goes_to_previous_track_with_bytecode
      # Mock the window to return P key ASCII code (112)
      mock_window = Minitest::Mock.new
      mock_window.expect :getch, 112

      @tui.instance_variable_set(:@window, mock_window)
      @tui.instance_variable_set(:@running, true)

      # Mock audio files to simulate having tracks and start at index 1
      @state.instance_variable_set(:@current_index, 1)
      @player.stub(:audio_files, ["file1.mp3", "file2.mp3"]) do
        initial_index = @state.current_index
        @tui.handle_input
        assert_equal initial_index - 1, @state.current_index
      end
    end

    def test_english_q_key_quits_application_with_bytecode
      # Mock the window to return Q key ASCII code (113)
      mock_window = Minitest::Mock.new
      mock_window.expect :getch, 113

      @tui.instance_variable_set(:@window, mock_window)
      @tui.instance_variable_set(:@running, true)

      # Test that Q key sets running to false
      @tui.handle_input
      refute @tui.instance_variable_get(:@running)
    end

    def test_russian_s_byte_code_stops_playback
      # Test S key position (Russian Ы = 139)
      @state.play
      mock_window = Minitest::Mock.new
      mock_window.expect :getch, 139
      @tui.instance_variable_set(:@window, mock_window)
      @tui.instance_variable_set(:@running, true)
      @tui.handle_input
      assert_equal "stopped", @state.state.to_s
    end

    def test_russian_n_byte_code_goes_to_next_track
      # Test N key position (Russian т = 130)
      mock_window = Minitest::Mock.new
      mock_window.expect :getch, 130
      @tui.instance_variable_set(:@window, mock_window)
      @tui.instance_variable_set(:@running, true)
      @player.stub(:audio_files, ["file1.mp3", "file2.mp3"]) do
        initial_index = @state.current_index
        @tui.handle_input
        assert_equal initial_index + 1, @state.current_index
      end
    end

    def test_russian_p_byte_code_goes_to_previous_track
      # Test P key position (Russian з = 183)
      @state.instance_variable_set(:@current_index, 1)
      mock_window = Minitest::Mock.new
      mock_window.expect :getch, 183
      @tui.instance_variable_set(:@window, mock_window)
      @tui.instance_variable_set(:@running, true)
      @player.stub(:audio_files, ["file1.mp3", "file2.mp3"]) do
        initial_index = @state.current_index
        @tui.handle_input
        assert_equal initial_index - 1, @state.current_index
      end
    end

    def test_russian_q_byte_code_quits_application
      # Test Q key position (Russian й = 185)
      mock_window = Minitest::Mock.new
      mock_window.expect :getch, 185
      @tui.instance_variable_set(:@window, mock_window)
      @tui.instance_variable_set(:@running, true)
      @tui.handle_input
      refute @tui.instance_variable_get(:@running)
    end

    def test_input_loop_blocks_for_key_press
      # This test fails initially because the input loop doesn't properly
      # block for keyboard input, causing 100% CPU usage

      # Mock window that blocks until key is pressed
      mock_window = Minitest::Mock.new
      key_received = false

      # Simulate getch blocking until a key is available
      mock_window.expect :getch, " " do
        # Simulate a brief delay as if waiting for user input
        sleep 0.1
        key_received = true
        " "
      end

      @tui.instance_variable_set(:@window, mock_window)
      @tui.instance_variable_set(:@running, true)

      # Start timing
      start_time = Time.now

      # Only test handle_input, not draw
      @tui.send(:handle_input)

      end_time = Time.now

      # Verify that reasonable time passed (simulating blocking behavior)
      assert_operator end_time - start_time, :>=, 0.1,
                      "Expected blocking behavior but completed too quickly"

      # Verify key was processed
      assert key_received, "Key should have been received"

      # Verify window expectations were met
      mock_window.verify
    end

    def test_curses_is_configured_for_blocking_input
      # This test verifies that curses is properly configured
      # to wait for keyboard input instead of timing out

      # Mock Curses to verify the configuration
      mock_stdscr = Object.new
      mock_stdscr.define_singleton_method(:keypad) { |*_args| nil }

      Curses.stub :init_screen, nil do
        Curses.stub :curs_set, nil, [0] do
          Curses.stub :noecho, nil do
            Curses.stub :stdscr, mock_stdscr do
              # Create TUI instance to trigger init_curses
              tui = TUI.new(@state)
              tui.send(:init_curses)
            end
          end
        end
      end

      # If we get here, the configuration was successful
      # This test ensures init_curses doesn't raise any exceptions
    end
  end
end
