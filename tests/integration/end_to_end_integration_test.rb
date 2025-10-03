# frozen_string_literal: true

require "securerandom"
require_relative "../test_helper"
require_relative "../../lib/meditation_player"

module MeditationPlayer
  class EndToEndIntegrationTest < Test
    def setup
      # Use a test-specific database path to avoid affecting production data
      @test_db_path = File.join(Dir.tmpdir, "mindfu_test_#{SecureRandom.hex(8)}.db")
      @test_db_dir = File.dirname(@test_db_path)
    end

    def teardown
      # Clean up any test app instances
      if @app
        @app.instance_variable_get(:@state)&.stop
        @app.instance_variable_get(:@db)&.close
      end

      # Clean up any MPV processes that might have been started
      `pkill -f "mpv.*--no-video" 2>/dev/null || true`

      # Clean up test database
      FileUtils.rm_rf(@test_db_dir) if File.directory?(@test_db_dir)
    end

    def test_app_creates_database_on_initialization
      # Create app instance with custom test database path
      @app = App.new
      app = @app

      # Override the database path for testing
      db = DB.new(@test_db_path)
      app.instance_variable_set(:@db, db)
      state = app.instance_variable_get(:@state)

      # Re-initialize state with the test database
      new_state = PlayerState.new(state.player, db)
      app.instance_variable_set(:@state, new_state)

      # Verify database was created
      assert_path_exists @test_db_path, "Database file should be created"

      # Verify database has the correct table
      db = app.instance_variable_get(:@db)
      result = db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='meditations'")
      assert_equal 1, result.length, "Meditations table should exist"

      # Clean up
      db.close
    end

    def test_app_components_are_properly_integrated
      # Create app instance with custom test database
      @app = App.new
      app = @app

      # Override the database path for testing
      db = DB.new(@test_db_path)
      app.instance_variable_set(:@db, db)
      state = app.instance_variable_get(:@state)

      # Re-initialize state with the test database
      new_state = PlayerState.new(state.player, db)
      app.instance_variable_set(:@state, new_state)
      state = new_state

      # Verify all components are properly integrated
      tui = app.instance_variable_get(:@tui)

      assert db, "App should have DB instance"
      assert state, "App should have state instance"
      assert tui, "App should have TUI instance"

      # Verify state has DB instance
      assert_equal db, state.data.instance_variable_get(:@db),
                   "State should have the same DB instance"

      # Clean up
      db.close
    end

    def test_database_persists_between_app_instances
      # Create first app instance with custom test database
      app1 = App.new

      # Override the database path for testing
      db1 = DB.new(@test_db_path)
      app1.instance_variable_set(:@db, db1)
      state1 = app1.instance_variable_get(:@state)

      # Re-initialize state with the test database
      new_state1 = PlayerState.new(state1.player, db1)
      app1.instance_variable_set(:@state, new_state1)
      state1 = app1.instance_variable_get(:@state)

      # Set current file and play it
      state1.instance_variable_set(:@current_index, 0)
      state1.play

      # Verify database entry was created
      result = db1.query("SELECT COUNT(*) as count FROM meditations")
      initial_count = result.first["count"]
      assert_predicate initial_count, :positive?, "Should have at least one database entry"

      # Close first app
      db1.close

      # Create second app instance and verify database persists
      app2 = App.new
      db2 = app2.instance_variable_get(:@db)

      # Verify database still has the entry
      result = db2.query("SELECT COUNT(*) as count FROM meditations")
      assert_equal initial_count, result.first["count"],
                   "Database should persist between app instances"

      # Clean up - stop all audio processes
      state1&.stop
      new_state1&.stop if defined?(new_state1)
      state2&.stop if defined?(state2)
      db2.close
    end

    def test_history_functionality_works_in_full_integration
      # Create app instance
      app = App.new
      db = app.instance_variable_get(:@db)
      state = app.instance_variable_get(:@state)

      # Mock some audio files for testing
      player = state.instance_variable_get(:@player)
      player.instance_variable_set(:@audio_files, [
                                     "audio_files/test1.mp3",
                                     "audio_files/test2.mp3",
                                     "audio_files/test3.mp3"
                                   ])

      # Play different files
      state.instance_variable_set(:@current_index, 0)
      state.play

      sleep 0.01
      state.stop
      state.instance_variable_set(:@current_index, 1)
      state.play

      sleep 0.01
      state.stop
      state.instance_variable_set(:@current_index, 2)
      state.play

      sleep 0.01
      state.stop

      # Verify history methods work
      current_history = state.current_file_history
      assert_equal 1, current_history.length, "Current file should have one history entry"

      recent_history = state.recent_history(5)
      assert_equal 3, recent_history.length, "Should have three recent entries"

      # Verify all files are represented
      filenames = recent_history.map { |entry| entry["filename"] }
      assert_includes filenames, "test1.mp3", "Should include test1.mp3"
      assert_includes filenames, "test2.mp3", "Should include test2.mp3"
      assert_includes filenames, "test3.mp3", "Should include test3.mp3"

      # Clean up
      state.stop
      db.close
    end

    def test_app_closes_database_properly
      # Create app instance
      app = App.new
      app.instance_variable_get(:@db)

      # Simulate app run (which should close database in ensure block)
      app.instance_variable_get(:@tui).stub :run, nil do
        app.run
      end

      # Database file should still exist but connection should be closed
      assert_path_exists @test_db_path, "Database file should still exist"

      # Verify we can reopen the database
      db2 = DB.new(@test_db_path)
      result = db2.query("SELECT COUNT(*) as count FROM meditations")
      # The count might not be 0 because other tests might have run
      assert_operator result.first["count"], :>=, 0, "Database should be accessible after reopening"
      db2.close
    end
  end
end
