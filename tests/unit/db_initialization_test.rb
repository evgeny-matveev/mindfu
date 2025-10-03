# frozen_string_literal: true

require_relative "../test_helper"
require_relative "../../lib/db"

module MeditationPlayer
  # Test database initialization and table structure
  class DBInitializationTest < Test
    def setup
      # Clean up any existing test database
      @test_db_path = "tmp/test_meditations_init.db"
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

    def test_database_initialization_creates_meditations_table
      db = DB.new(@test_db_path)

      # Verify table was created by querying sqlite_master
      result = db.query("SELECT name FROM sqlite_master WHERE type='table' AND name='meditations'")
      assert_equal 1, result.length, "meditations table should exist"
      assert_equal "meditations", result.first["name"], "Table name should be 'meditations'"
    end

    def test_meditations_table_has_correct_columns
      db = DB.new(@test_db_path)

      # Query table schema
      result = db.query("PRAGMA table_info(meditations)")

      # Verify columns exist
      columns = result.map { |row| row["name"] }
      assert_includes columns, "id", "Table should have 'id' column"
      assert_includes columns, "filename", "Table should have 'filename' column"
      assert_includes columns, "played_at", "Table should have 'played_at' column"
      assert_includes columns, "update_at", "Table should have 'update_at' column"
      assert_includes columns, "duration", "Table should have 'duration' column"
    end

    def test_meditations_table_has_correct_column_types
      db = DB.new(@test_db_path)

      # Query table schema
      result = db.query("PRAGMA table_info(meditations)")

      # Verify column types
      id_column = result.find { |row| row["name"] == "id" }
      assert_equal "INTEGER", id_column["type"], "id column should be INTEGER"

      filename_column = result.find { |row| row["name"] == "filename" }
      assert_equal "TEXT", filename_column["type"], "filename column should be TEXT"

      played_at_column = result.find { |row| row["name"] == "played_at" }
      assert_equal "DATETIME", played_at_column["type"], "played_at column should be DATETIME"
    end

    def test_database_file_is_created
      DB.new(@test_db_path)

      assert_path_exists @test_db_path, "Database file should be created"
    end

    def test_database_persists_data
      # First database instance
      db1 = DB.new(@test_db_path)
      db1.execute("INSERT INTO meditations (filename, played_at) VALUES (?, ?)",
                  ["persistence_test.mp3", "2025-09-30 20:00:00"])

      # Close first instance (if there's a close method)
      db1.close if db1.respond_to?(:close)

      # Second database instance
      db2 = DB.new(@test_db_path)
      result = db2.query("SELECT filename FROM meditations WHERE filename = ?",
                         ["persistence_test.mp3"])

      assert_equal 1, result.length, "Data should persist across database instances"
      assert_equal "persistence_test.mp3", result.first["filename"], "Persisted data should match"
    end
  end
end
