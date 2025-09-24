require 'state_machines'

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
    attr_reader :player, :current_index

    # Initialize player state with audio player
    #
    # @param player [AudioPlayer] the audio player instance
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
        transition [:playing, :paused] => :stopped
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

    def go_to_next
      return if audio_files.empty?

      @current_index = (@current_index + 1) % audio_files.length
      play_current_file if playing?
    end

    def go_to_previous
      return if audio_files.empty?

      @current_index = @current_index.zero? ? audio_files.length - 1 : @current_index - 1
      play_current_file if playing?
    end
  end
end