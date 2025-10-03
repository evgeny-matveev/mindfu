# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/db"

module MeditationPlayer
  # Test database query and execution methods
  class DBQueryExecutionTest < Test
    def setup
      # Clean up any existing test database
      @test_db_path = "tmp/test_meditations_query.db"
      FileUtils.rm_f(@test_db_path)

      # Ensure tmp directory exists
      FileUtils.mkdir_p("tmp")
    end

    def teardown
      # Clean up test database
      FileUtils.rm_f(@test_db_path)
    end

    def test_query_method_exists
      db = DB.new(@test_db_path)
      assert_respond_to db, :query, "DB instance should respond to query method"
    end

    def test_execute_method_exists
      db = DB.new(@test_db_path)
      assert_respond_to db, :execute, "DB instance should respond to execute method"
    end

    def test_query_with_select_statement
      db = DB.new(@test_db_path)

      # Insert test data first
      db.execute("INSERT INTO meditations (filename, played_at) VALUES (?, ?)",
                 ["test1.mp3", "2025-09-30 10:00:00"])

      # Query the data
      result = db.query("SELECT * FROM meditations WHERE filename = ?", ["test1.mp3"])

      assert_equal 1, result.length, "Should find one record"
      assert_equal "test1.mp3", result.first["filename"], "Filename should match"
      assert_equal "2025-09-30 10:00:00", result.first["played_at"], "Played_at should match"
    end

    def test_execute_with_insert_statement
      db = DB.new(@test_db_path)

      # Insert a record
      db.execute("INSERT INTO meditations (filename, played_at) VALUES (?, ?)",
                 ["test2.mp3", "2025-09-30 11:00:00"])

      # Verify it was inserted
      result = db.query("SELECT COUNT(*) as count FROM meditations")
      assert_equal 1, result.first["count"], "Should have one record"
    end

    def test_execute_with_update_statement
      db = DB.new(@test_db_path)

      # Insert initial record
      db.execute("INSERT INTO meditations (filename, played_at) VALUES (?, ?)",
                 ["test3.mp3", "2025-09-30 12:00:00"])

      # Update the record
      db.execute("UPDATE meditations SET filename = ? WHERE filename = ?",
                 ["updated.mp3", "test3.mp3"])

      # Verify it was updated
      result = db.query("SELECT filename FROM meditations WHERE filename = ?", ["updated.mp3"])
      assert_equal 1, result.length, "Should find updated record"

      old_result = db.query("SELECT filename FROM meditations WHERE filename = ?", ["test3.mp3"])
      assert_equal 0, old_result.length, "Should not find old record"
    end

    def test_execute_with_delete_statement
      db = DB.new(@test_db_path)

      # Insert test data
      db.execute("INSERT INTO meditations (filename, played_at) VALUES (?, ?)",
                 ["test4.mp3", "2025-09-30 13:00:00"])

      # Delete the record
      db.execute("DELETE FROM meditations WHERE filename = ?", ["test4.mp3"])

      # Verify it was deleted
      result = db.query("SELECT COUNT(*) as count FROM meditations")
      assert_equal 0, result.first["count"], "Should have no records"
    end

    def test_query_orders_by_played_at_desc
      db = DB.new(@test_db_path)

      # Insert test data in chronological order
      db.execute("INSERT INTO meditations (filename, played_at) VALUES (?, ?)",
                 ["first.mp3", "2025-09-30 10:00:00"])
      db.execute("INSERT INTO meditations (filename, played_at) VALUES (?, ?)",
                 ["second.mp3", "2025-09-30 11:00:00"])
      db.execute("INSERT INTO meditations (filename, played_at) VALUES (?, ?)",
                 ["third.mp3", "2025-09-30 12:00:00"])

      # Query with ORDER BY played_at DESC
      result = db.query("SELECT filename FROM meditations ORDER BY played_at DESC")

      # Should be in reverse chronological order
      assert_equal "third.mp3", result.first["filename"], "First result should be most recent"
      assert_equal "second.mp3", result[1]["filename"], "Second result should be middle"
      assert_equal "first.mp3", result.last["filename"], "Last result should be oldest"
    end

    def test_query_with_empty_result_set
      db = DB.new(@test_db_path)

      # Query empty table
      result = db.query("SELECT * FROM meditations")

      assert_empty result, "Result should be empty for empty table"
    end

    def test_query_with_no_matching_records
      db = DB.new(@test_db_path)

      # Insert test data
      db.execute("INSERT INTO meditations (filename, played_at) VALUES (?, ?)",
                 ["existing.mp3", "2025-09-30 14:00:00"])

      # Query for non-existent record
      result = db.query("SELECT * FROM meditations WHERE filename = ?", ["nonexistent.mp3"])

      assert_empty result, "Result should be empty for non-existent record"
    end

    def test_error_handling_for_invalid_sql
      db = DB.new(@test_db_path)

      # Test with invalid SQL syntax
      assert_raises SQLite3::Exception do
        db.query("INVALID SQL STATEMENT")
      end
    end

    def test_error_handling_for_invalid_parameters
      db = DB.new(@test_db_path)

      # Test with insufficient parameters
      assert_raises SQLite3::Exception do
        db.execute("INSERT INTO meditations (filename, played_at) VALUES (?, ?)",
                   ["only_one_param"])
      end
    end

    def test_duplicate_entries_are_allowed
      db = DB.new(@test_db_path)

      # Insert same filename twice
      db.execute("INSERT INTO meditations (filename, played_at) VALUES (?, ?)",
                 ["duplicate.mp3", "2025-09-30 15:00:00"])
      db.execute("INSERT INTO meditations (filename, played_at) VALUES (?, ?)",
                 ["duplicate.mp3", "2025-09-30 16:00:00"])

      # Both should exist
      result = db.query("SELECT COUNT(*) as count FROM meditations WHERE filename = ?",
                        ["duplicate.mp3"])
      assert_equal 2, result.first["count"], "Should have two duplicate entries"
    end

    def test_query_with_datetime_parameter
      db = DB.new(@test_db_path)

      # Insert with datetime
      test_time = "2025-09-30 17:00:00"
      db.execute("INSERT INTO meditations (filename, played_at) VALUES (?, ?)",
                 ["datetime_test.mp3", test_time])

      # Query with datetime parameter
      result = db.query("SELECT * FROM meditations WHERE played_at = ?", [test_time])

      assert_equal 1, result.length, "Should find record with matching datetime"
      assert_equal "datetime_test.mp3", result.first["filename"], "Filename should match"
    end

    def test_query_with_like_operator
      db = DB.new(@test_db_path)

      # Insert test data
      db.execute("INSERT INTO meditations (filename, played_at) VALUES (?, ?)",
                 ["test_like.mp3", "2025-09-30 18:00:00"])
      db.execute("INSERT INTO meditations (filename, played_at) VALUES (?, ?)",
                 ["another_test.mp3", "2025-09-30 19:00:00"])

      # Query with LIKE
      result = db.query("SELECT filename FROM meditations WHERE filename LIKE ?", ["%test%"])

      assert_equal 2, result.length, "Should find both records containing 'test'"
    end
  end
end
