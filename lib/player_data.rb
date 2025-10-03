# frozen_string_literal: true

require_relative "db"

module MeditationPlayer
  # Data access and query methods for player state
  # Handles all data retrieval, navigation, and formatting operations
  #
  # This class is responsible for:
  # - File navigation and selection
  # - History queries and formatting
  # - Statistics retrieval
  # - Time formatting helpers
  #
  # @author Yevgeny Matveyev
  # @since 1.0.0
  class PlayerData
    attr_reader :player, :db, :current_index

    # Initialize player data with player and database
    #
    # @param player [MPVPlayer] the audio player instance
    # @param db [DB, nil] optional database instance for history tracking
    # @param current_index [Integer] initial file index
    # @return [PlayerData] new instance
    def initialize(player, db = nil, current_index = nil)
      @player = player
      @db = db
      @current_index = current_index || random_index
    end

    def audio_files
      player.audio_files
    end

    def current_file
      audio_files[current_index] if current_index && audio_files[current_index]
    end

    def current_filename
      current_file ? File.basename(current_file) : nil
    end

    # Get play history for current file
    #
    # Retrieves all play history entries for the currently selected file.
    #
    # @return [Array<Hash>] array of play history entries with played_at timestamps
    def current_file_history
      return [] unless current_file && @db

      begin
        @db.query(
          "SELECT played_at FROM meditations WHERE filename = ? ORDER BY played_at DESC",
          [current_filename]
        )
      rescue SQLite3::Exception => e
        warn "Failed to retrieve current file history: #{e.message}"
        []
      end
    end

    # Get most recently played files
    #
    # Retrieves the most recently played files across all meditation files.
    #
    # @param limit [Integer] maximum number of records to return (default: 10)
    # @return [Array<Hash>] array of recent play history entries
    def recent_history(limit = 10)
      return [] unless @db

      begin
        @db.query(
          "SELECT filename, played_at FROM meditations WHERE entry_type = 'recent' " \
          "ORDER BY played_at DESC LIMIT ?",
          [limit]
        )
      rescue SQLite3::Exception => e
        warn "Failed to retrieve recent history: #{e.message}"
        []
      end
    end

    # Get a random file index, excluding recently played files
    #
    # @return [Integer] random index within available audio files range
    def random_index
      return 0 if audio_files.empty?

      # Get recently played filenames (last 10)
      recent_files = get_recently_played_filenames(10)

      # Get available indices that aren't recently played
      available_indices = []
      audio_files.each_with_index do |file_path, index|
        filename = File.basename(file_path)
        available_indices << index unless recent_files.include?(filename)
      end

      # If all files are recently played (or very few files), fall back to random from all files
      if available_indices.empty?
        rand(audio_files.length)
      else
        available_indices.sample
      end
    end

    # Get recently played filenames
    #
    # @param limit [Integer] maximum number of filenames to return
    # @return [Array<String>] array of recently played filenames
    def get_recently_played_filenames(limit = 10)
      return [] unless @db

      begin
        recent_history(limit).map { |entry| entry["filename"] }
      rescue SQLite3::Exception => e
        warn "Failed to get recently played filenames: #{e.message}"
        []
      end
    end

    def next
      @current_index = (@current_index + 1) % audio_files.length
    end

    def previous
      @current_index = (@current_index - 1) % audio_files.length
    end

    # Get formatted recent history for display
    #
    # @param limit [Integer] maximum number of entries to return (default: 10)
    # @return [Array<Hash>] array of formatted history entries with filename and time_ago
    def formatted_recent_history(limit = 10)
      return [] unless @db

      begin
        raw_history = @db.query(
          "SELECT filename, played_at FROM meditations WHERE entry_type = 'recent' " \
          "ORDER BY played_at DESC LIMIT ?",
          [limit]
        )

        raw_history.map.with_index do |entry, index|
          filename = entry["filename"]
          # Remove extension from filename for display
          display_name = File.basename(filename, File.extname(filename))

          {
            rank: index + 1,
            filename: display_name,
            time_ago: format_time_ago(parse_time(entry["played_at"]))
          }
        end
      rescue SQLite3::Exception => e
        warn "Failed to retrieve formatted recent history: #{e.message}"
        []
      end
    end

    # Get file duration
    #
    # Attempts to get the duration of the current audio file.
    #
    # @param filename [String] name of the audio file
    # @return [Integer, nil] duration in seconds, or nil if not available
    def get_file_duration(filename)
      # Try to get duration from MPV if currently playing
      @player.total_duration.to_i if @player.current_file == filename && @player.total_duration

      # For future implementation: could use audio metadata libraries
      # to get duration without playing the file
      nil
    end

    # Get completion statistics
    #
    # Retrieves meditation completion statistics from the database.
    #
    # @return [Hash] hash containing completion statistics
    def completion_stats
      return {} unless @db

      begin
        @db.completion_stats
      rescue SQLite3::Exception => e
        warn "Failed to get completion stats: #{e.message}"
        {}
      end
    end

    private

    def parse_time(time_string)
      Time.strptime(time_string, "%Y-%m-%d %H:%M:%S")
    rescue StandardError
      Time.now
    end

    def format_time_ago(time)
      return "" unless time.is_a?(Time)

      seconds = Time.now - time
      days = (seconds / 86_400).to_i

      case days
      when 0
        "today"
      when 1
        "yesterday"
      when 2..6
        "#{days} days ago"
      when 7..13
        "1 week ago"
      when 14..20
        "2 weeks ago"
      when 21..27
        "3 weeks ago"
      when 28..34
        "4 weeks ago"
      else
        months = (days / 30.44).to_i
        if months == 1
          "1 month ago"
        else
          "#{months} months ago"
        end
      end
    end
  end
end
