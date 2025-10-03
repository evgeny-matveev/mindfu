# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/db"

module MeditationPlayer
  # Test meditation-specific database operations
  class DBMeditationTest < Test
    def setup
      # Clean up any existing test database
      @test_db_path = "tmp/test_meditations_meditation.db"
      FileUtils.rm_f(@test_db_path)

      # Ensure tmp directory exists
      FileUtils.mkdir_p("tmp")
    end

    def teardown
      # Clean up test database
      FileUtils.rm_f(@test_db_path)
    end

    def test_record_playback_start_creates_new_record
      db = DB.new(@test_db_path)

      # Record playback start
      record_id = db.record_playback_start("test_meditation.mp3", 300)

      # Verify record was created
      result = db.query("SELECT * FROM meditations WHERE id = ?", [record_id])
      assert_equal 1, result.length, "Should find the created record"
      assert_equal "test_meditation.mp3", result.first["filename"]
      assert_equal 300, result.first["duration"]
    end

    def test_record_playback_start_updates_existing_incomplete_record
      db = DB.new(@test_db_path)

      # Create initial incomplete record
      db.execute("INSERT INTO meditations (filename, played_at, duration) VALUES (?, ?, ?)",
                 ["test_meditation.mp3", "2025-09-30 10:00:00", 300])

      # Record new playback start (should update existing)
      db.record_playback_start("test_meditation.mp3", 300)

      # Verify only one record exists
      result = db.query("SELECT COUNT(*) as count FROM meditations WHERE filename = ?",
                        ["test_meditation.mp3"])
      assert_equal 1, result.first["count"], "Should have only one record"

      # Verify timestamp was updated
      records = db.query("SELECT played_at FROM meditations WHERE filename = ?",
                         ["test_meditation.mp3"])
      refute_equal "2025-09-30 10:00:00", records.first["played_at"],
                   "Played_at should be updated"
    end

    def test_record_playback_completion_updates_existing_record
      db = DB.new(@test_db_path)

      # Create incomplete record
      db.execute("INSERT INTO meditations (filename, played_at, duration) VALUES (?, ?, ?)",
                 ["test_meditation.mp3", "2025-09-30 10:00:00", 300])

      # Record completion
      affected_rows = db.record_playback_completion("test_meditation.mp3")

      assert_equal 1, affected_rows, "Should update one record"

      # Verify update_at was set
      result = db.query("SELECT update_at FROM meditations WHERE filename = ?",
                        ["test_meditation.mp3"])
      refute_nil result.first["update_at"], "update_at should be set"
    end

    def test_record_playback_completion_does_nothing_without_incomplete_record
      db = DB.new(@test_db_path)

      # Create completed record
      db.execute(
        "INSERT INTO meditations (filename, played_at, update_at, duration) VALUES (?, ?, ?, ?)",
        ["test_meditation.mp3", "2025-09-30 10:00:00", "2025-09-30 10:05:00", 300]
      )

      # Try to record completion
      affected_rows = db.record_playback_completion("test_meditation.mp3")

      assert_equal 0, affected_rows, "Should not update completed record"
    end

    def test_completion_stats_with_no_data
      db = DB.new(@test_db_path)

      stats = db.completion_stats

      assert_equal 0, stats[:total_sessions], "Should have 0 total sessions"
      assert_equal 0, stats[:completed_sessions], "Should have 0 completed sessions"
      assert_equal 0, stats[:completion_rate], "Should have 0% completion rate"
    end

    def test_completion_stats_with_incomplete_sessions_only
      db = DB.new(@test_db_path)

      # Create incomplete records
      db.execute("INSERT INTO meditations (filename, played_at, duration) VALUES (?, ?, ?)",
                 ["meditation1.mp3", "2025-09-30 10:00:00", 300])
      db.execute("INSERT INTO meditations (filename, played_at, duration) VALUES (?, ?, ?)",
                 ["meditation2.mp3", "2025-09-30 11:00:00", 300])

      stats = db.completion_stats

      assert_equal 2, stats[:total_sessions], "Should have 2 total sessions"
      assert_equal 0, stats[:completed_sessions], "Should have 0 completed sessions"
      assert_equal 0, stats[:completion_rate], "Should have 0% completion rate"
    end

    def test_completion_stats_with_completed_sessions_only
      db = DB.new(@test_db_path)

      # Create completed records
      db.execute(
        "INSERT INTO meditations (filename, played_at, update_at, duration) VALUES (?, ?, ?, ?)",
        ["meditation1.mp3", "2025-09-30 10:00:00", "2025-09-30 10:05:00", 300]
      )
      db.execute(
        "INSERT INTO meditations (filename, played_at, update_at, duration) VALUES (?, ?, ?, ?)",
        ["meditation2.mp3", "2025-09-30 11:00:00", "2025-09-30 11:06:00", 300]
      )

      stats = db.completion_stats

      assert_equal 2, stats[:total_sessions], "Should have 2 total sessions"
      assert_equal 2, stats[:completed_sessions], "Should have 2 completed sessions"
      assert_in_delta(100.0, stats[:completion_rate], 0.001, "Should have 100% completion rate")
    end

    def test_completion_stats_with_mixed_sessions
      db = DB.new(@test_db_path)

      # Create mixed records
      db.execute("INSERT INTO meditations (filename, played_at, duration) VALUES (?, ?, ?)",
                 ["incomplete1.mp3", "2025-09-30 10:00:00", 300])
      db.execute(
        "INSERT INTO meditations (filename, played_at, update_at, duration) VALUES (?, ?, ?, ?)",
        ["completed1.mp3", "2025-09-30 11:00:00", "2025-09-30 11:05:00", 300]
      )
      db.execute("INSERT INTO meditations (filename, played_at, duration) VALUES (?, ?, ?)",
                 ["incomplete2.mp3", "2025-09-30 12:00:00", 300])
      db.execute(
        "INSERT INTO meditations (filename, played_at, update_at, duration) VALUES (?, ?, ?, ?)",
        ["completed2.mp3", "2025-09-30 13:00:00", "2025-09-30 13:07:00", 300]
      )

      stats = db.completion_stats

      assert_equal 4, stats[:total_sessions], "Should have 4 total sessions"
      assert_equal 2, stats[:completed_sessions], "Should have 2 completed sessions"
      assert_in_delta(50.0, stats[:completion_rate], 0.001, "Should have 50% completion rate")
    end

    def test_completion_stats_handles_zero_division
      db = DB.new(@test_db_path)

      stats = db.completion_stats

      # Should not raise division by zero error
      assert_equal 0, stats[:completion_rate], "Should handle zero total sessions"
    end
  end
end
