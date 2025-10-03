# frozen_string_literal: true

require "state_machines"
require_relative "player_data"
require_relative "player_actions"

module MeditationPlayer
  # Player state machine managing playback controls and file navigation
  # Handles play/pause operations with state transitions using composition
  #
  # This class manages the player's state machine and delegates to specialized
  # classes for data access and actions. Provides a clean interface for controlling
  # audio playback and state transitions.
  #
  # @author Yevgeny Matveyev
  # @since 1.0.0
  class PlayerState
    attr_reader :data, :player

    # Initialize player state with audio player
    #
    # @param player [MPVPlayer] the audio player instance
    # @param db [DB, nil] optional database instance for history tracking
    # @return [PlayerState] new instance
    def initialize(player, db = nil)
      @player = player
      @data = PlayerData.new(player, db)
      @actions = PlayerActions.new(@data)
      super()
    end

    # Delegate common data access methods to data object
    def current_index
      @data.current_index
    end

    def current_file
      @data.current_file
    end

    def current_filename
      @data.current_filename
    end

    def audio_files
      @data.audio_files
    end

    def current_file_history
      @data.current_file_history
    end

    def recent_history(limit = 10)
      @data.recent_history(limit)
    end

    def formatted_recent_history(limit = 10)
      @data.formatted_recent_history(limit)
    end

    def completion_stats
      @data.completion_stats
    end

    # Delegate navigation methods to data object
    def next
      @data.next
    end

    def previous
      @data.previous
    end

    # State machine definition
    state_machine initial: :stopped do
      event :play do
        transition stopped: :playing, paused: :playing
      end

      event :resume do
        transition paused: :playing
      end

      event :pause do
        transition playing: :paused
      end

      event :stop do
        transition %i[playing paused] => :stopped
      end

      before_transition on: :play, do: :play_current_file
      after_transition on: :pause, do: :pause_playback
      after_transition on: :resume, do: :resume_playback
      after_transition on: :stop, do: :stop_playback
      after_transition on: :play, do: :record_play_history
      after_transition on: :stop, do: :handle_stop_event
    end

    private

    # Delegate action methods to actions object
    def play_current_file
      @actions.play_current_file
    end

    def pause_playback
      @actions.pause_playback
    end

    def resume_playback
      @actions.resume_playback
    end

    def stop_playback
      @actions.stop_playback
    end

    def record_play_history
      @actions.record_play_history
    end

    def handle_stop_event
      @actions.handle_stop_event
    end

    # Handle playback completion
    #
    # Called when playback completes naturally (not user-initiated stop).
    # Resets completion flag and transitions to stopped state.
    #
    # @return [void]
    def on_playback_completion
      @actions.on_playback_completion
      # Transition to stopped state, which will trigger handle_stop_event
      stop if playing?
    end
  end
end
