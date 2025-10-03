# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/db"

module MeditationPlayer
  # Basic DB smoke test - verifies core functionality works
  class DBTest < Test
    def setup
      # Clean up any existing test database
      @test_db_path = "tmp/test_meditations.db"
      FileUtils.rm_f(@test_db_path)

      # Ensure tmp directory exists
      FileUtils.mkdir_p("tmp")
    end

    def teardown
      # Clean up test database
      FileUtils.rm_f(@test_db_path)
    end

    def test_db_class_exists
      assert DB, "DB class should be defined"
    end

    def test_basic_database_operations_work
      db = DB.new(@test_db_path)

      # Test basic insert/query
      db.execute("INSERT INTO meditations (filename, played_at) VALUES (?, ?)",
                 ["basic_test.mp3", "2025-09-30 10:00:00"])

      result = db.query("SELECT * FROM meditations WHERE filename = ?", ["basic_test.mp3"])
      assert_equal 1, result.length, "Basic insert/query should work"
      assert_equal "basic_test.mp3", result.first["filename"]
    end

    def test_meditation_specific_methods_exist
      db = DB.new(@test_db_path)

      assert_respond_to db, :record_playback_start, "Should have record_playback_start method"
      assert_respond_to db, :record_playback_completion,
                        "Should have record_playback_completion method"
      assert_respond_to db, :completion_stats, "Should have completion_stats method"
    end

    def test_database_can_be_closed
      db = DB.new(@test_db_path)
      assert_respond_to db, :close, "Should have close method"

      # Should not raise an error
      db.close
    end
  end
end
