# frozen_string_literal: true

require "sqlite3"
require "fileutils"

# Database management class for meditation player
# Handles SQLite database operations with parameter binding and error handling
class DB
  # Initializes a new database connection
  #
  # Creates a new DB instance and establishes connection to the SQLite database.
  # If no path is provided, uses the default path in the user's home directory.
  #
  # @param db_path [String, nil] Path to the SQLite database file
  # @return [DB] A new DB instance
  #
  # @example Initialize with default path
  #   db = DB.new
  #
  # @example Initialize with custom path
  #   db = DB.new("/path/to/custom/database.db")
  def initialize(db_path = nil)
    # Use test database if in test environment, otherwise use production database
    @db_path = if db_path
                 db_path
               elsif ENV["TEST"] == "true"
                 File.join(__dir__, "..", "tmp", "test_meditations.db")
               else
                 # Use local directory for production database
                 File.join(__dir__, "..", "meditations.db")
               end
    @db = nil
    initialize_database
  end

  # Executes a SQL query with parameter binding
  #
  # This method provides secure query execution using parameter binding to prevent
  # SQL injection attacks. It prepares the statement, binds parameters, and returns
  # the results as an array of hashes with column names as keys.
  #
  # @param sql [String] SQL query with ? placeholders for parameters
  # @param params [Array] Array of parameter values to bind to the query
  # @return [Array<Hash>] Array of result hashes with column names as keys
  # @raise [SQLite3::Exception] if query execution fails
  #
  # @example Basic query
  #   db.query("SELECT * FROM meditations")
  #
  # @example Query with parameters
  #   db.query("SELECT * FROM meditations WHERE filename = ?", ["meditation.mp3"])
  #
  # @see #execute
  def query(sql, params = [])
    ensure_connection
    statement = @db.prepare(sql)
    result = []

    params.each_with_index do |param, index|
      statement.bind_param(index + 1, param)
    end

    rows = statement.execute

    # Get column names from the statement
    columns = statement.columns

    rows.each do |row|
      result_hash = {}
      columns.each_with_index do |column, index|
        result_hash[column] = row[index]
      end
      result << result_hash
    end

    result
  rescue SQLite3::Exception => e
    raise SQLite3::Exception, "Query failed: #{e.message}"
  ensure
    statement&.close
  end

  # Executes a SQL statement that doesn't return results (INSERT, UPDATE, DELETE)
  #
  # This method is used for SQL statements that modify data or schema but don't
  # return result sets. It uses parameter binding for security and returns the
  # number of rows affected by the operation.
  #
  # @param sql [String] SQL statement with ? placeholders for parameters
  # @param params [Array] Array of parameter values to bind to the statement
  # @return [Integer] Number of rows affected by the operation
  # @raise [SQLite3::Exception] if statement execution fails
  #
  # @example Insert operation
  #   db.execute("INSERT INTO meditations (filename, played_at) VALUES (?, ?)",
  #              ["meditation.mp3", Time.now])
  #
  # @example Update operation
  #   db.execute("UPDATE meditations SET played_at = ? WHERE id = ?",
  #              [Time.now, 1])
  #
  # @see #query
  def execute(sql, params = [])
    ensure_connection
    statement = @db.prepare(sql)

    params.each_with_index do |param, index|
      statement.bind_param(index + 1, param)
    end

    statement.execute
    @db.changes
  rescue SQLite3::Exception => e
    raise SQLite3::Exception, "Execute failed: #{e.message}"
  ensure
    statement&.close
  end

  # Record meditation playback start
  #
  # Records when a meditation file starts playing with both played_at and update_at timestamps
  # for new records, or only updates played_at for existing records that were skipped.
  #
  # @param filename [String] name of the meditation file
  # @param duration [Integer, nil] duration of the meditation in seconds
  # @return [Integer] ID of the inserted/updated record
  # @raise [SQLite3::Exception] if database operation fails
  #
  # @example Record playback start
  #   db.record_playback_start("meditation.mp3", 300)
  def record_playback_start(filename, duration = nil)
    ensure_connection

    # Check if there's an existing record for this filename that doesn't have update_at
    # (meaning it was started but not completed)
    existing_records = query("SELECT id FROM meditations WHERE filename = ? AND update_at IS NULL",
                             [filename])

    if existing_records.any?
      # Update existing record with new played_at timestamp
      execute("UPDATE meditations SET played_at = ? WHERE id = ?",
              [Time.now.strftime("%Y-%m-%d %H:%M:%S"), existing_records.first["id"]])
      existing_records.first["id"]
    else
      # Insert new record with both played_at and duration
      execute("INSERT INTO meditations (filename, played_at, duration) VALUES (?, ?, ?)",
              [filename, Time.now.strftime("%Y-%m-%d %H:%M:%S"), duration])
      @db.last_insert_row_id
    end
  rescue SQLite3::Exception => e
    raise SQLite3::Exception, "Failed to record playback start: #{e.message}"
  end

  # Record meditation playback completion
  #
  # Updates a meditation record with completion timestamp when playback finishes naturally.
  #
  # @param filename [String] name of the meditation file
  # @return [Integer] Number of rows affected
  # @raise [SQLite3::Exception] if database operation fails
  #
  # @example Record playback completion
  #   db.record_playback_completion("meditation.mp3")
  def record_playback_completion(filename)
    ensure_connection

    # Find the most recent record for this filename that doesn't have update_at
    existing_records = query(
      "SELECT id FROM meditations WHERE filename = ? AND update_at IS NULL " \
      "ORDER BY played_at DESC LIMIT 1", [filename]
    )

    if existing_records.any?
      execute("UPDATE meditations SET update_at = ? WHERE id = ?",
              [Time.now.strftime("%Y-%m-%d %H:%M:%S"), existing_records.first["id"]])
    else
      0
    end
  rescue SQLite3::Exception => e
    raise SQLite3::Exception, "Failed to record playback completion: #{e.message}"
  end

  # Record recent play worthy entry
  #
  # Records a meditation entry that has reached significant playback percentage.
  # This creates a separate entry from the initial 'start' entry for recently played tracking.
  #
  # @param filename [String] name of the meditation file
  # @param duration [Integer, nil] duration of the meditation in seconds
  # @return [Integer] ID of the inserted record
  # @raise [SQLite3::Exception] if database operation fails
  #
  # @example Record recent play
  #   db.record_recent_play("meditation.mp3", 300)
  def record_recent_play(filename, duration = nil)
    ensure_connection

    execute(
      "INSERT INTO meditations (filename, played_at, entry_type, duration) VALUES (?, ?, ?, ?)",
      [filename, Time.now.strftime("%Y-%m-%d %H:%M:%S"), "recent", duration]
    )
    @db.last_insert_row_id
  rescue SQLite3::Exception => e
    raise SQLite3::Exception, "Failed to record recent play: #{e.message}"
  end

  # Get meditation completion statistics
  #
  # Retrieves statistics about meditation completion rates.
  #
  # @return [Hash] Hash containing completion statistics
  # @raise [SQLite3::Exception] if database operation fails
  #
  # @example Get completion stats
  #   stats = db.completion_stats
  #   puts stats[:completion_rate]
  def completion_stats
    ensure_connection

    # Get total meditation sessions
    total_sessions = query("SELECT COUNT(*) as count FROM meditations").first["count"]

    # Get completed meditation sessions (those with update_at)
    completed_sessions = query(
      "SELECT COUNT(*) as count FROM meditations WHERE update_at IS NOT NULL"
    ).first["count"]

    # Calculate completion rate
    completion_rate = if total_sessions.positive?
                        (completed_sessions.to_f / total_sessions * 100).round(2)
                      else
                        0
                      end

    {
      total_sessions: total_sessions,
      completed_sessions: completed_sessions,
      completion_rate: completion_rate
    }
  rescue SQLite3::Exception => e
    raise SQLite3::Exception, "Failed to get completion stats: #{e.message}"
  end

  def close
    @db&.close
    @db = nil
  end

  private

  # Ensures database connection is active
  #
  # This private method checks if the database connection is active and
  # establishes a new connection if needed. It's called automatically
  # before any database operation.
  #
  # @return [void]
  # @api private
  def ensure_connection
    @db = SQLite3::Database.new(@db_path) if @db.nil? || @db.closed?
  end

  # Initializes the database and creates necessary tables
  #
  # This private method is called during object initialization to:
  # 1. Create the database directory if it doesn't exist
  # 2. Create the SQLite database file
  # 3. Create the meditations table with proper schema
  #
  # @return [void]
  # @raise [SQLite3::Exception] if database initialization fails
  # @api private
  def initialize_database
    # Ensure directory exists
    db_dir = File.dirname(@db_path)
    FileUtils.mkdir_p(db_dir) unless File.directory?(db_dir)

    # Create database and table if they don't exist
    @db = SQLite3::Database.new(@db_path)

    # Create meditations table if it doesn't exist
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS meditations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        filename TEXT NOT NULL,
        played_at DATETIME NOT NULL,
        update_at DATETIME,
        duration INTEGER
      )
    SQL

    # Check if update_at column exists, add it if it doesn't (for backward compatibility)
    begin
      @db.execute("SELECT update_at FROM meditations LIMIT 1")
    rescue SQLite3::Exception
      # Column doesn't exist, add it
      @db.execute("ALTER TABLE meditations ADD COLUMN update_at DATETIME")
    end

    # Check if duration column exists, add it if it doesn't (for backward compatibility)
    begin
      @db.execute("SELECT duration FROM meditations LIMIT 1")
    rescue SQLite3::Exception
      # Column doesn't exist, add it
      @db.execute("ALTER TABLE meditations ADD COLUMN duration INTEGER")
    end

    # Check if entry_type column exists, add it if it doesn't (for percentage-based tracking)
    begin
      @db.execute("SELECT entry_type FROM meditations LIMIT 1")
    rescue SQLite3::Exception
      # Column doesn't exist, add it
      @db.execute("ALTER TABLE meditations ADD COLUMN entry_type TEXT DEFAULT 'start'")
    end

    # Keep connection open for lazy initialization
  rescue SQLite3::Exception => e
    raise SQLite3::Exception, "Database initialization failed: #{e.message}"
  end
end
