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
    # Maximum percentage of files to exclude from random selection
    MAX_RECENT_PERCENTAGE = 0.9
    # Persistence file for recently played files
    RECENTLY_PLAYED_FILE = "recently_played.json"

    # Initialize RandomFileSelector with player state
    #
    # @param state [PlayerState] the player state for audio file access
    # @return [RandomFileSelector] new instance
    def initialize(state)
      @state = state
      @session_history = []
      @recently_played_files = load_recently_played
      @current_position = -1
    end

    # Select a random file from available files, excluding recently played ones
    #
    # Implements the 90% rule: excludes up to 90% of files that were recently played
    # Prefers non-recently played files when available
    # Falls back to any file if all files are recently played
    #
    # @return [String, nil] selected random filename or nil if no files available
    def select_random_file
      available_files = @state.player.audio_files
      return nil if available_files.empty?

      # Get files that aren't recently played
      candidates = available_files - @recently_played_files

      # If we have candidates that aren't recently played, prefer them
      # Only fall back if we have no candidates
      candidates = available_files if candidates.empty?

      candidates.sample
    end

    # Record a file as played and update recently played history
    #
    # Adds the file to both session history and persistent recently played files.
    # Enforces the 90% limit on recently played files.
    #
    # @param filename [String] the filename that was played
    # @return [void]
    def record_played_file(filename)
      return unless filename && @state.player.audio_files.include?(filename)

      # Add to session history
      @session_history << filename
      @current_position = @session_history.length - 1

      # Add to recently played and enforce limit
      @recently_played_files << filename
      enforce_recently_played_limit
      save_recently_played
    end

    # Get the next random file and add to session history
    #
    # @return [String, nil] next random filename or nil if no files available
    def next_random_file
      next_file = select_random_file
      record_played_file(next_file) if next_file
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
      record_played_file(initial_file) if initial_file
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
      return [] unless File.exist?(RECENTLY_PLAYED_FILE)

      begin
        data = JSON.parse(File.read(RECENTLY_PLAYED_FILE))
        data["recently_played"] || []
      rescue JSON::ParserError, Errno::ENOENT
        []
      end
    end

    # Save recently played files to persistence
    #
    # @return [void]
    def save_recently_played
      data = {
        recently_played: @recently_played_files,
        timestamp: Time.now.iso8601
      }

      File.write(RECENTLY_PLAYED_FILE, JSON.pretty_generate(data))
    end

    # Enforce the 90% limit on recently played files
    #
    # Removes oldest files from recently played history to maintain
    # only 90% of total available files maximum.
    #
    # @return [void]
    def enforce_recently_played_limit
      max_recent = (@state.player.audio_files.length * MAX_RECENT_PERCENTAGE).to_i
      max_recent = [max_recent, 1].max # Always keep at least 1

      @recently_played_files.shift while @recently_played_files.length > max_recent
    end
  end
end
