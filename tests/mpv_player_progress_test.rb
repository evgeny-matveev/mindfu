# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/mpv_player"

module MeditationPlayer
  class MPVPlayerProgressTest < Test
    def setup
      @player = MPVPlayer.new
      @test_file = audio_files.first
    end

    def teardown
      @player.stop
    end

    def audio_files
      # Use real audio files for integration testing when available
      Dir.glob(File.join(MPVPlayer::AUDIO_DIR, "*.{mp3,mp4,wav,ogg}"))
    end

    def test_progress_queries_mpv_directly
      skip "Needs mpv installation and audio files" if audio_files.empty?

      @player.play(@test_file)
      sleep 0.1 # Let it start playing

      progress = @player.current_progress
      assert_kind_of Float, progress
      assert_operator progress, :>=, 0.0
      assert_operator progress, :<=, 1.0
    end

    def test_progress_is_accurate_during_playback
      mock_mpv_with_progress_tracking do
        @player.play(@test_file)

        # Mock different time positions
        mock_mpv_position(15.0) # 15 seconds in
        progress_15s = @player.current_progress
        assert_in_delta 0.25, progress_15s, 0.01 # 15/60 = 0.25

        mock_mpv_position(30.0) # 30 seconds in
        progress_30s = @player.current_progress
        assert_in_delta 0.5, progress_30s, 0.01 # 30/60 = 0.5

        # Verify progress increases
        assert_operator progress_30s, :>, progress_15s
      end
    end

    def test_progress_remains_constant_when_paused
      mock_mpv_with_progress_tracking do
        @player.play(@test_file)
        mock_mpv_position(20.0)

        @player.pause
        progress_paused = @player.current_progress

        # Simulate time passing while paused
        sleep 0.1
        progress_still_paused = @player.current_progress

        assert_equal progress_paused, progress_still_paused
      end
    end

    def test_progress_continues_from_correct_position_after_resume
      mock_mpv_with_progress_tracking do
        @player.play(@test_file)
        mock_mpv_position(20.0)

        @player.pause
        progress_before_resume = @player.current_progress

        @player.resume
        # Progress should continue from paused position
        progress_after_resume = @player.current_progress

        assert_equal progress_before_resume, progress_after_resume
      end
    end

    def test_progress_capped_at_100_percent
      mock_mpv_with_progress_tracking do
        @player.play(@test_file)

        # Mock position beyond duration
        mock_mpv_position(75.0) # Beyond 60s duration
        progress = @player.current_progress

        assert_in_delta 1.0, progress, 0.01
      end
    end

    def test_progress_handles_zero_duration
      mock_mpv_with_progress_tracking do
        @player.play(@test_file)

        # Mock zero duration
        @player.instance_variable_set(:@duration, 0.0)
        mock_mpv_position(10.0)

        progress = @player.current_progress
        assert_in_delta(0.0, progress)
      end
    end

    def test_progress_handles_nil_duration
      mock_mpv_with_progress_tracking do
        @player.play(@test_file)

        # Mock nil duration
        @player.instance_variable_set(:@duration, nil)
        mock_mpv_position(10.0)

        progress = @player.current_progress
        assert_in_delta(0.0, progress)
      end
    end

    def test_stop_returns_final_progress
      mock_mpv_with_progress_tracking do
        @player.play(@test_file)
        mock_mpv_position(45.0) # 45 seconds in

        progress = @player.stop
        assert_in_delta 0.75, progress, 0.01 # 45/60 = 0.75
      end
    end

    def test_progress_with_mpv_ipc_errors
      mock_mpv_with_progress_tracking do
        @player.play(@test_file)

        # Mock IPC communication failure
        def @player.send_command(_command, *_args)
          raise Errno::ENOENT, "No such file or directory"
        end

        progress = @player.current_progress
        assert_in_delta(0.0, progress)
      end
    end

    def test_progress_with_invalid_json_response
      mock_mpv_with_progress_tracking do
        @player.play(@test_file)

        # Mock invalid JSON response
        def @player.send_command(_command, *_args)
          "invalid json response"
        end

        progress = @player.current_progress
        assert_in_delta(0.0, progress)
      end
    end

    def test_progress_with_mpv_property_errors
      mock_mpv_with_progress_tracking do
        @player.play(@test_file)

        # Mock MPV property error response
        def @player.send_command(_command, *_args)
          { "error" => "property not found" }.to_json
        end

        progress = @player.current_progress
        assert_in_delta(0.0, progress)
      end
    end

    private

    def mock_mpv_with_progress_tracking
      # Mock mpv process with accurate progress tracking
      def @player.spawn_mpv(*args)
        @mpv_pid = 12_345
        @mpv_socket = "/tmp/mpvsocket_test_#{object_id}"
        @current_file = args.last
        @playing = true
        @paused = false
        @current_position = 0.0
        @duration = 60.0 # Mock 60-second duration
      end

      def @player.send_command(command, *args)
        return nil unless @mpv_socket

        case command
        when "get_property"
          case args.first
          when "time-pos"
            { "data" => @current_position }
          when "duration"
            { "data" => @duration }
          when "pause"
            { "data" => @paused }
          else
            { "data" => nil }
          end
        when "set_property"
          case args.first
          when "pause"
            @paused = args.last
          end
          { "data" => true }
        else
          { "data" => nil }
        end
      end

      def @player.mpv_process_running?
        @mpv_pid && @playing
      end

      def @player.playing?
        @playing && !@paused
      end

      def @player.paused?
        @paused
      end

      def @player.terminate_mpv_process
        @mpv_pid = nil
        @playing = false
        @paused = false
        @current_position = 0.0
      end

      yield
    end

    def mock_mpv_position(position)
      @player.instance_variable_set(:@current_position, position)
    end
  end
end
