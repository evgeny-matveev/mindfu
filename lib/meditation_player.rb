# frozen_string_literal: true

require_relative "mpv_player"
require_relative "player_state"
require_relative "tui"

module MeditationPlayer
  # Main application controller for the meditation audio player
  #
  # This class coordinates all components of the meditation player:
  # audio playback, state management, and user interface.
  #
  # @author Yevgeny Matveyev
  # @since 1.0.0
  class App
    # Initialize the meditation player application
    #
    # Sets up all necessary components: audio player, state machine,
    # and user interface.
    #
    # @return [App] new instance
    def initialize
      @player = MPVPlayer.new
      @state = PlayerState.new(@player)
      @tui = TUI.new(@state)
    end

    # Run the meditation player application
    #
    # Starts the user interface with a fresh random file selection.
    #
    # @return [void]
    def run
      @tui.run
    ensure
      @state.stop
    end
  end
end
