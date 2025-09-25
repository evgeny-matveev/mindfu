# frozen_string_literal: true

require "json"

module MeditationPlayer
  # Handles random file selection with session history tracking
  #
  # This class is responsible for:
  # - Selecting random audio files for playback
  # - Maintaining a history of recently played files across sessions
  # - Tracking session history for next/previous navigation
  # - Ensuring random selection excludes recently played files (90% rule)
  #
  # @author Your Name
  # @since 1.0.0
  class RandomFileSelector
    # Maximum number of recently played files to exclude from random selection
    MAX_RECENT_FILES = 10
    # Persistence file for recently played files
    RECENTLY_PLAYED_FILE = "tmp/recently_played.json"
    # Test-specific persistence file
    TEST_RECENTLY_PLAYED_FILE = "tmp/test_recently_played.json"

    # Initialize RandomFileSelector with player state
    #
    # @param state [PlayerState] the player state for audio file access
    # @param test_mode [Boolean] whether to use test-specific state file
    # @return [RandomFileSelector] new instance
    def initialize(state, test_mode: false)
      @state = state
      @test_mode = test_mode
      @session_history = []
      @recently_played_files = load_recently_played
      @current_position = -1
    end

    # Select a random file from available files, excluding recently played ones
    #
    # Implements the last-10 rule: excludes up to 10 files that were recently played
    # Prefers non-recently played files when available
    # Falls back to any file if all files are recently played
    #
    # @return [String, nil] selected random filename or nil if no files available
    def select_random_file
      available_files = @state.player.audio_files
      return nil if available_files.empty?

      # Convert recently played basenames to full paths for comparison
      recently_played_full_paths = @recently_played_files.filter_map do |basename|
        available_files.find { |full_path| File.basename(full_path) == basename }
      end

      # Get files that aren't recently played
      candidates = available_files - recently_played_full_paths

      # If we have candidates that aren't recently played, prefer them
      # Only fall back if we have no candidates
      candidates = available_files if candidates.empty?

      candidates.sample
    end

    # Record a file as played and update recently played history
    #
    # Adds the file to both session history and persistent recently played files.
    # Enforces the last-10 limit on recently played files.
    #
    # @param filename [String] the filename that was played
    # @return [void]
    def record_played_file(filename)
      return unless filename

      # Convert to basename for storage and comparison
      basename = File.basename(filename)

      # Check if the basename exists in available files
      available_basenames = @state.player.audio_files.map { |f| File.basename(f) }
      return unless available_basenames.include?(basename)

      # Add to session history
      @session_history << filename
      @current_position = @session_history.length - 1

      # Add to recently played and enforce limit
      @recently_played_files << basename
      enforce_recently_played_limit
      save_recently_played
    end

    # Get the next random file and add to session history
    #
    # @return [String, nil] next random filename or nil if no files available
    def next_random_file
      next_file = select_random_file
      add_to_session_history(next_file) if next_file
      next_file
    end

    # Get the previous file from session history
    #
    # Navigates backwards through the current session's playback history.
    # Does not remove files from history, allowing back-and-forth navigation.
    # Returns the file before the current one in the history.
    #
    # @return [String, nil] previous filename or nil if no history available
    def previous_file
      return nil if @session_history.empty? || @current_position <= 0

      # Move back in history and return the file
      @current_position -= 1
      @session_history[@current_position]
    end

    # Add a file to session history
    #
    # @param filename [String] the filename to add to history
    # @return [void]
    def add_to_session_history(filename)
      @session_history << filename if filename
      @current_position = @session_history.length - 1
    end

    # Initialize a new session with a random file
    #
    # @return [String, nil] initial random filename or nil if no files available
    def initialize_session
      initial_file = select_random_file
      add_to_session_history(initial_file) if initial_file
      initial_file
    end

    # Get the current session history
    #
    # @return [Array<String>] array of filenames in session history
    def session_history
      @session_history.dup
    end

    private

    # Load recently played files from persistence
    #
    # @return [Array<String>] array of recently played filenames
    def load_recently_played
      file_to_load = @test_mode ? TEST_RECENTLY_PLAYED_FILE : RECENTLY_PLAYED_FILE
      return [] unless File.exist?(file_to_load)

      begin
        data = JSON.parse(File.read(file_to_load))
        data["recently_played"] || []
      rescue JSON::ParserError, Errno::ENOENT
        []
      end
    end

    # Save recently played files to persistence
    #
    # @return [void]
    def save_recently_played
      file_to_save = @test_mode ? TEST_RECENTLY_PLAYED_FILE : RECENTLY_PLAYED_FILE
      data = {
        recently_played: @recently_played_files,
        timestamp: Time.now.iso8601
      }

      File.write(file_to_save, JSON.pretty_generate(data))
    end

    # Enforce the last-10 limit on recently played files
    #
    # Removes oldest files from recently played history to maintain
    # only 10 files maximum.
    #
    # @return [void]
    def enforce_recently_played_limit
      # Keep only the last MAX_RECENT_FILES (10) files
      @recently_played_files.shift while @recently_played_files.length > MAX_RECENT_FILES
    end
  end
end
