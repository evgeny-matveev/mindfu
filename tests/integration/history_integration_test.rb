# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/db"
require_relative "../../lib/player_state"
require_relative "../../lib/mpv_player"

module MeditationPlayer
  class HistoryIntegrationTest < Test
    def setup
      # Clean up any existing test database
      @test_db_path = "tmp/test_history_integration.db"
      FileUtils.rm_f(@test_db_path)

      # Ensure tmp directory exists
      FileUtils.mkdir_p("tmp")

      # Create test database and player
      @db = DB.new(@test_db_path)
      @player = MPVPlayer.new
      @state = PlayerState.new(@player, @db)

      # Mock some audio files for testing
      @player.instance_variable_set(:@audio_files, [
                                      "audio_files/test1.mp3",
                                      "audio_files/test2.mp3",
                                      "audio_files/test3.mp3"
                                    ])
    end

    def teardown
      # Stop any playing audio
      @state.stop if @state.respond_to?(:stop)
      @player.stop if @player.respond_to?(:stop)

      # Clean up test database
      @db&.close
      FileUtils.rm_f(@test_db_path)
    end

    def test_player_state_accepts_db_instance
      assert @state.data.instance_variable_get(:@db),
             "PlayerState should store DB instance in data object"
      assert_equal @db, @state.data.instance_variable_get(:@db), "DB instance should match"
    end

    def test_player_state_works_without_db
      state_without_db = PlayerState.new(@player)
      assert_nil state_without_db.data.instance_variable_get(:@db),
                 "DB should be nil when not provided"

      # Should still function normally
      assert_respond_to state_without_db, :play
      assert_respond_to state_without_db, :pause
      assert_respond_to state_without_db, :stop
    end

    def test_record_play_history_creates_database_entry
      # Set current file
      @state.data.instance_variable_set(:@current_index, 0)

      # Trigger play transition
      @state.play

      # Verify database entry was created
      result = @db.query("SELECT * FROM meditations WHERE filename = ?", ["test1.mp3"])
      assert_equal 1, result.length, "Should have one database entry"
      assert_equal "test1.mp3", result.first["filename"], "Filename should match"
      assert result.first["played_at"], "Played_at should be set"
    end

    def test_current_file_history_returns_play_history
      # Set current file and play it twice
      @state.data.instance_variable_set(:@current_index, 0)
      @state.play

      # Play again (different timestamp)
      sleep 0.01 # Ensure different timestamp
      @state.stop
      @state.play

      # Get history
      history = @state.current_file_history
      assert_equal 1, history.length, "Should have one history entry (reusing existing record)"
      assert history.first["played_at"], "History entries should have timestamps"
    end

    def test_recent_history_returns_most_recent_files
      # Play different files
      @state.data.instance_variable_set(:@current_index, 0)
      @state.play

      sleep 0.01
      @state.stop
      @state.data.instance_variable_set(:@current_index, 1)
      @state.play

      sleep 0.01
      @state.stop
      @state.data.instance_variable_set(:@current_index, 2)
      @state.play

      # Get recent history
      recent = @state.recent_history(5)
      assert_equal 3, recent.length, "Should have three recent entries"

      # Check that timestamps are in descending order
      timestamps = recent.map { |entry| entry["played_at"] }
      assert_operator timestamps.first, :>=, timestamps.last,
                      "Most recent should have latest timestamp"

      # Check that all files are represented
      filenames = recent.map { |entry| entry["filename"] }
      assert_includes filenames, "test1.mp3", "Should include test1.mp3"
      assert_includes filenames, "test2.mp3", "Should include test2.mp3"
      assert_includes filenames, "test3.mp3", "Should include test3.mp3"
    end

    def test_recent_history_respects_limit
      # Play multiple files
      5.times do |i|
        @state.stop if @state.playing?
        @state.data.instance_variable_set(:@current_index, i % 3)
        @state.play
        sleep 0.01
      end

      # Get recent history with limit
      recent = @state.recent_history(2)
      assert_equal 2, recent.length, "Should respect limit parameter"
    end

    def test_history_methods_return_empty_arrays_without_db
      state_without_db = PlayerState.new(@player)

      assert_empty state_without_db.current_file_history, "Should return empty array without DB"
      assert_empty state_without_db.recent_history, "Should return empty array without DB"
    end

    def test_database_errors_are_handled_gracefully
      # Mock database to raise an exception
      mock_db = Minitest::Mock.new
      mock_db.expect :record_playback_start, lambda {
        raise SQLite3::Exception, "Database error"
      }, [String, NilClass]

      state_with_failing_db = PlayerState.new(@player, mock_db)
      state_with_failing_db.data.instance_variable_set(:@current_index, 0)

      # Should not raise an exception
      begin
        state_with_failing_db.play
        pass # No exception was raised
      rescue SQLite3::Exception
        flunk "Database exception was not handled gracefully"
      end

      mock_db.verify
    end

    def test_history_query_errors_are_handled_gracefully
      # Create a real database for this test
      test_db_path = "tmp/test_error_handling.db"
      FileUtils.rm_f(test_db_path)

      begin
        # Create database but then corrupt it by removing the file
        db = DB.new(test_db_path)
        FileUtils.rm_f(test_db_path)

        state_with_failing_db = PlayerState.new(@player, db)
        # Set current file for history
        state_with_failing_db.data.instance_variable_set(:@current_index, 0)

        # Should return empty array instead of raising
        history = state_with_failing_db.current_file_history
        assert_empty history, "Should return empty array on query error"

        recent = state_with_failing_db.recent_history
        assert_empty recent, "Should return empty array on query error"
      ensure
        db&.close
        FileUtils.rm_f(test_db_path)
      end
    end

    def test_play_history_not_recorded_when_no_current_file
      # Set invalid index (no current file)
      @state.data.instance_variable_set(:@current_index, 999)

      # Trigger play transition
      @state.play

      # Verify no database entry was created
      result = @db.query("SELECT COUNT(*) as count FROM meditations")
      assert_equal 0, result.first["count"], "Should have no database entries without current file"
    end

    def test_integration_with_full_app_cycle
      # Test the complete integration as it would work in the actual app
      require_relative "../../lib/meditation_player"

      # Create a temporary app instance
      app = App.new

      # Verify all components are properly integrated
      assert app.instance_variable_get(:@db), "App should have DB instance"
      assert app.instance_variable_get(:@state).data.instance_variable_get(:@db),
             "State should have DB instance"

      # Clean up
      app.instance_variable_get(:@db).close
    end
  end
end
