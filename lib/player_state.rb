# frozen_string_literal: true

require "state_machines"

module MeditationPlayer
  # Player state machine managing playback controls and file navigation
  # Handles play/pause operations with state transitions
  #
  # This class manages the player's state machine and provides a clean interface
  # for controlling audio playback and state transitions.
  #
  # @author Yevgeny Matveyev
  # @since 1.0.0
  class PlayerState
    attr_reader :player, :current_index

    # Initialize player state with audio player
    #
    # @param player [MPVPlayer] the audio player instance
    # @return [PlayerState] new instance
    def initialize(player)
      @player = player
      @current_index = 0
      super()
    end

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
    end

    # Get list of available audio files from player
    #
    # @return [Array<String>] array of audio file paths
    def audio_files
      player.audio_files
    end

    # Get path to current audio file
    #
    # @return [String, nil] path to current file or nil
    def current_file
      audio_files[current_index] if current_index && audio_files[current_index]
    end

    # Get filename of current audio file
    #
    # @return [String, nil] filename without path or nil
    def current_filename
      current_file ? File.basename(current_file) : nil
    end

    private

    def play_current_file
      file = current_file
      player.play(file) if file
    end

    def pause_playback
      player.pause
    end

    def resume_playback
      player.resume
    end

    def stop_playback
      player.stop
    end
  end
end
