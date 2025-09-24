require_relative 'test_helper'

module MeditationPlayer
  class PlayerStateTest < Test
    def setup
      @player = AudioPlayer.new
      @state = PlayerState.new(@player)
    end

    def teardown
      @player.stop if @player
    end

    def test_initial_state_is_stopped
      assert_equal "stopped", @state.state.to_s
    end

    def test_play_transitions_to_playing
      @state.play
      assert_equal "playing", @state.state.to_s
    end

    def test_pause_transitions_to_paused
      @state.play
      @state.pause
      assert_equal "paused", @state.state.to_s
    end

    def test_resume_transitions_to_playing
      @state.play
      @state.pause
      @state.resume
      assert_equal "playing", @state.state.to_s
    end

    def test_stop_from_playing_goes_to_stopped
      @state.play
      @state.stop
      assert_equal "stopped", @state.state.to_s
    end

    def test_stop_from_paused_goes_to_stopped
      @state.play
      @state.pause
      @state.stop
      assert_equal "stopped", @state.state.to_s
    end

    def test_current_index_initially_zero
      assert_equal 0, @state.current_index
    end

    def test_audio_files_delegated_to_player
      assert_equal @player.audio_files, @state.audio_files
    end

    def test_next_track_changes_index
      # Mock audio files to simulate having tracks
      @player.stub(:audio_files, ['file1.mp3', 'file2.mp3']) do
        @state.next
        assert_equal 1, @state.current_index
      end
    end

    def test_previous_track_wraps_around
      # Mock audio files to simulate having tracks
      @player.stub(:audio_files, ['file1.mp3', 'file2.mp3']) do
        @state.previous
        assert_equal 1, @state.current_index
      end
    end

    def test_state_machine_has_all_expected_states
      # Test that we can transition to all expected states
      @state.play
      assert_includes ["playing", "paused", "stopped"], @state.state.to_s

      @state.pause if @state.state.to_s == "playing"
      assert_includes ["playing", "paused", "stopped"], @state.state.to_s

      @state.stop
      assert_equal "stopped", @state.state.to_s
    end

    def test_state_machine_has_all_expected_events
      # Test that all expected events can be called
      [:play, :pause, :resume, :stop, :next, :previous].each do |event|
        assert_respond_to @state, event
      end
    end
  end
end