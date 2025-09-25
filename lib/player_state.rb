# frozen_string_literal: true

require "state_machines"
require_relative "random_file_selector"

module MeditationPlayer
  # Player state machine managing playback controls and file navigation
  # Handles play/pause/next/prev operations with state transitions
  #
  # This class manages the player's state machine and provides a clean interface
  # for controlling audio playback, including file navigation and state transitions.
  #
  # @author Your Name
  # @since 1.0.0
  class PlayerState
    attr_reader :player, :current_index, :random_selector

    # Initialize player state with audio player
    #
    # @param player [MPVPlayer] the audio player instance
    # @return [PlayerState] new instance
    def initialize(player)
      @player = player
      @current_index = 0
      @random_selector = RandomFileSelector.new(self, test_mode: false)
      @random_mode = true
      initialize_random_session
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

      event :next do
        transition any => same
      end

      event :previous do
        transition any => same
      end

      before_transition on: :play, do: :play_current_file
      after_transition on: :pause, do: :pause_playback
      after_transition on: :resume, do: :resume_playback
      after_transition on: :stop, do: :stop_playback
      after_transition on: :next, do: :go_to_next
      after_transition on: :previous, do: :go_to_previous
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

    # Initialize random session with a random starting file
    #
    # @return [void]
    def initialize_random_session
      return if audio_files.empty?

      initial_file = @random_selector.initialize_session
      @current_index = audio_files.index(initial_file) if initial_file
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
      progress = player.stop
      # Only mark as completed if 90% or more was played
      # Use the full path from the player, not the basename
      current_file_path = @player.instance_variable_get(:@current_file)
      @random_selector.record_played_file(current_file_path) if progress >= 0.9 && current_file_path
    end

    def go_to_next
      return if audio_files.empty?

      # Stop current file and check progress before moving to next
      progress = player.stop
      # Only mark as completed if 90% or more was played
      # Use the full path from the player, not the basename
      current_file_path = @player.instance_variable_get(:@current_file)
      @random_selector.record_played_file(current_file_path) if progress >= 0.9 && current_file_path

      if @random_mode
        next_file = @random_selector.next_random_file
        if next_file
          @current_index = audio_files.index(next_file)
          play_current_file if playing?
        end
      else
        @current_index = (@current_index + 1) % audio_files.length
        play_current_file if playing?
      end
    end

    def go_to_previous
      return if audio_files.empty?

      if @random_mode
        prev_file = @random_selector.previous_file
        if prev_file
          @current_index = audio_files.index(prev_file)
          play_current_file if playing?
        end
      else
        @current_index = @current_index.zero? ? audio_files.length - 1 : @current_index - 1
        play_current_file if playing?
      end
    end
  end
end
