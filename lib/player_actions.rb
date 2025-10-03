# frozen_string_literal: true

require_relative "db"

module MeditationPlayer
  # Action and state transition methods for player state
  # Handles all playback actions and state transitions
  #
  # This class is responsible for:
  # - Playback control (play, pause, resume, stop)
  # - Database operations (recording history, completion)
  # - Event handling (completion callbacks)
  # - State transition logic
  #
  # @author Yevgeny Matveyev
  # @since 1.0.0
  class PlayerActions
    # Initialize player actions with data object
    #
    # @param data [PlayerData] the data object for file and database access
    # @return [PlayerActions] new instance
    def initialize(data)
      @data = data
      @naturally_completed = false
      @has_recorded_recent_play = false

      # Set up completion callback
      @data.player.set_completion_callback { method(:on_playback_completion) }

      # Set up progress callback for percentage-based tracking
      @data.player.set_progress_callback { |percentage| handle_progress_threshold(percentage) }
    end

    def play_current_file
      file = @data.current_file
      @data.player.play(file) if file
    end

    def pause_playback
      @data.player.pause
    end

    def resume_playback
      @data.player.resume
    end

    def stop_playback
      @data.player.stop
    end

    # Record play history in database
    #
    # Records the current file being played to the database with timestamp.
    # Uses the new database methods for better completion tracking.
    # Now only records initial playback start, recently played is handled by progress callback.
    # Gracefully handles database errors to maintain application stability.
    #
    # @return [void]
    def record_play_history
      return unless @data.current_file && @data.db

      filename = @data.current_filename
      duration = @data.get_file_duration(filename)

      begin
        @data.db.record_playback_start(filename, duration)
        # Reset the recent play tracking flag for new playback
        @has_recorded_recent_play = false
      rescue SQLite3::Exception => e
        # Log error but don't crash the application
        warn "Failed to record play history: #{e.message}"
      end
    end

    # Handle stop event
    #
    # Distinguishes between natural completion and user-initiated stop.
    # Only records completion if playback finished naturally.
    #
    # @return [void]
    def handle_stop_event
      return unless @data.current_file && @data.db

      # If playback completed naturally, record completion
      if @naturally_completed
        filename = @data.current_filename
        begin
          @data.db.record_playback_completion(filename)
        rescue SQLite3::Exception => e
          warn "Failed to record playback completion: #{e.message}"
        end
      end

      # Reset completion flag
      @naturally_completed = false
    end

    # Handle playback completion
    #
    # Called when playback completes naturally (not user-initiated stop).
    #
    # @return [void]
    def on_playback_completion
      @naturally_completed = true
      # State machine should handle the transition to stopped state
      # This method just records that completion occurred naturally
    end

    # Handle progress threshold reached
    #
    # Called when playback reaches significant percentage thresholds (50%, 90%).
    # Records to recently played only after meaningful listening has occurred.
    #
    # @param percentage [Integer] the percentage threshold reached (50 or 90)
    # @return [void]
    def handle_progress_threshold(percentage)
      return unless @data.current_file && @data.db
      return if @has_recorded_recent_play

      # Only record to recently played after 50% playback
      return unless percentage >= 50

      filename = @data.current_filename

      begin
        # Use record_recent_play to add to recently played
        @data.db.record_recent_play(filename, @data.get_file_duration(filename))
        @has_recorded_recent_play = true
      rescue SQLite3::Exception => e
        warn "Failed to record recent play: #{e.message}"
      end
    end
  end
end
