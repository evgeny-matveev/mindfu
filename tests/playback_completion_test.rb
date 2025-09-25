# frozen_string_literal: true

require_relative "test_helper"

module MeditationPlayer
  class PlaybackCompletionTest < Test
    def setup
      @player = MPVPlayer.new
      @test_file = File.join(Dir.pwd, "low_bass_sine.mp3")

      # Mock the player to return only our test file
      @player.stub(:audio_files, [@test_file]) do
        @state = PlayerState.new(@player)
        # Set the current index to our test file
        @state.instance_variable_set(:@current_index, 0)
      end
    end

    def teardown
      @player&.stop
    end

    def test_natural_completion_updates_history_when_90_percent_played
      # Use the actual low_bass_sine.mp3 file
      assert_path_exists @test_file, "Test file should exist"

      mock_mpv_spawn do
        # Clear session history before test
        @state.random_selector.instance_variable_set(:@session_history, [])
        @state.random_selector.instance_variable_set(:@recently_played_files, [])

        # Manually set the current file to our test file
        @state.instance_variable_set(:@current_index, 0)

        @player.play(@test_file)

        # Simulate process completion with 95% progress
        @player.instance_variable_set(:@playing, false)
        @player.instance_variable_set(:@mpv_pid, nil)

        # Mock the current progress to return 0.95
        def @player.current_progress
          0.95
        end

        # Mock process_running? to return false (process terminated)
        def @player.process_running?(_pid)
          false
        end

        # Check completion should trigger callback
        @player.check_completion

        # Verify the file was recorded in history
        refute_empty @state.random_selector.session_history
        assert_equal @test_file, @state.random_selector.session_history.last

        # Verify it was added to recently played files as basename
        recently_played = @state.random_selector.instance_variable_get(:@recently_played_files)
        assert_includes recently_played, File.basename(@test_file)
      end
    end

    def test_natural_completion_does_not_update_history_when_less_than_90_percent
      # Use the actual low_bass_sine.mp3 file
      assert_path_exists @test_file, "Test file should exist"

      mock_mpv_spawn do
        # Clear session history before test
        @state.random_selector.instance_variable_set(:@session_history, [])
        @state.random_selector.instance_variable_set(:@recently_played_files, [])

        @player.play(@test_file)

        # Simulate process completion with 85% progress
        @player.instance_variable_set(:@playing, false)
        @player.instance_variable_set(:@mpv_pid, nil)

        # Mock the current progress to return 0.85
        def @player.current_progress
          0.85
        end

        # Mock process_running? to return false (process terminated)
        def @player.process_running?(_pid)
          false
        end

        # Check completion should trigger callback
        @player.check_completion

        # Verify the file was NOT recorded in history
        assert_empty @state.random_selector.session_history

        # Verify it was NOT added to recently played files
        recently_played = @state.random_selector.instance_variable_get(:@recently_played_files)
        refute_includes recently_played, File.basename(@test_file)
      end
    end

    def test_natural_completion_transitions_to_stopped_state
      # Use the actual low_bass_sine.mp3 file
      assert_path_exists @test_file, "Test file should exist"

      mock_mpv_spawn do
        # Manually set the current file to our test file
        @state.instance_variable_set(:@current_index, 0)

        @player.play(@test_file)
        assert_equal "playing", @state.state.to_s

        # Simulate process completion with 95% progress
        @player.instance_variable_set(:@playing, false)
        @player.instance_variable_set(:@mpv_pid, nil)

        # Mock the current progress to return 0.95
        def @player.current_progress
          0.95
        end

        # Mock process_running? to return false (process terminated)
        def @player.process_running?(_pid)
          false
        end

        # Check completion should trigger callback
        @player.check_completion

        # Verify state transitioned to stopped
        assert_equal "stopped", @state.state.to_s
      end
    end

    def test_playback_completed_detects_terminated_process
      mock_mpv_spawn do
        @player.play(@test_file)

        # Initially should not be completed
        refute_predicate @player, :playback_completed?

        # Simulate process termination by making process_running? return false
        def @player.process_running?(_pid)
          false
        end

        # Now should be completed
        assert_predicate @player, :playback_completed?
      end
    end

    def test_playback_completed_returns_false_when_not_playing
      refute_predicate @player, :playback_completed?
    end

    def test_completion_callback_is_called_with_progress
      mock_mpv_spawn do
        callback_called = false
        callback_progress = nil

        @player.on_completion do |progress|
          callback_called = true
          callback_progress = progress
        end

        @player.play(@test_file)

        # Simulate process completion by making process_running? return false
        def @player.process_running?(_pid)
          false
        end

        # Mock the current progress to return 0.95
        def @player.current_progress
          0.95
        end

        # Check completion should trigger callback
        @player.check_completion

        # Verify callback was called with correct progress
        assert callback_called
        assert_in_delta 0.95, callback_progress
      end
    end

    def test_state_check_completion_calls_player_check_completion
      mock_mpv_spawn do
        @player.play(@test_file)

        # Mock the player's check_completion method
        def @player.check_completion
          @check_completion_called = true
        end

        # Call state's check_completion using send to access private method
        @state.send(:check_completion)

        # Verify player's check_completion was called
        assert @check_completion_called
      end
    end

    def test_completion_at_exactly_90_percent_updates_history
      # Test the boundary case - exactly 90% should update history
      assert_path_exists @test_file, "Test file should exist"

      mock_mpv_spawn do
        # Clear session history before test
        @state.random_selector.instance_variable_set(:@session_history, [])
        @state.random_selector.instance_variable_set(:@recently_played_files, [])

        @player.play(@test_file)

        # Simulate process completion with exactly 90% progress
        @player.instance_variable_set(:@playing, false)
        @player.instance_variable_set(:@mpv_pid, nil)

        # Mock the current progress to return exactly 0.90
        def @player.current_progress
          0.90
        end

        # Mock process_running? to return false (process terminated)
        def @player.process_running?(_pid)
          false
        end

        # Check completion should trigger callback
        @player.check_completion

        # Verify the file was recorded in history
        refute_empty @state.random_selector.session_history
        assert_equal @test_file, @state.random_selector.session_history.last

        # Verify it was added to recently played files as basename
        recently_played = @state.random_selector.instance_variable_get(:@recently_played_files)
        assert_includes recently_played, File.basename(@test_file)
      end
    end

    def test_completion_at_89_percent_does_not_update_history
      # Test the boundary case - just below 90% should not update history
      assert_path_exists @test_file, "Test file should exist"

      mock_mpv_spawn do
        # Clear session history before test
        @state.random_selector.instance_variable_set(:@session_history, [])
        @state.random_selector.instance_variable_set(:@recently_played_files, [])

        @player.play(@test_file)

        # Simulate process completion with 89% progress
        @player.instance_variable_set(:@playing, false)
        @player.instance_variable_set(:@mpv_pid, nil)

        # Mock the current progress to return 0.89
        def @player.current_progress
          0.89
        end

        # Mock process_running? to return false (process terminated)
        def @player.process_running?(_pid)
          false
        end

        # Check completion should trigger callback
        @player.check_completion

        # Verify the file was NOT recorded in history
        assert_empty @state.random_selector.session_history

        # Verify it was NOT added to recently played files
        recently_played = @state.random_selector.instance_variable_get(:@recently_played_files)
        refute_includes recently_played, File.basename(@test_file)
      end
    end

    private

    def mock_mpv_spawn
      # Mock the player to return only our test file
      @player.stub(:audio_files, [@test_file]) do
        # Mock the spawn method to avoid actually starting mpv
        def @player.spawn_mpv(*args)
          @mpv_pid = 12_345 # Mock PID
          @mpv_socket = "/tmp/mpvsocket_test_#{object_id}"

          # Create a mock socket file
          File.write(@mpv_socket, "") if @mpv_socket

          @current_file = args.last
          @playing = true
          @paused = false
        end

        # Mock process termination
        def @player.terminate_mpv_process
          @mpv_pid = nil
          @current_file = nil
          @playing = false
          @paused = false

          # Clean up socket file
          File.delete(@mpv_socket) if @mpv_socket && File.exist?(@mpv_socket)
          @mpv_socket = nil
        end

        yield
      end
    end
  end
end
