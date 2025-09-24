require_relative 'audio_player'
require_relative 'player_state'
require_relative 'tui'
require_relative 'state_persistence'

module MeditationPlayer
  # Main application controller for the meditation audio player
  #
  # This class coordinates all components of the meditation player:
  # audio playback, state management, user interface, and persistence.
  #
  # @author Your Name
  # @since 1.0.0
  class App
    # Initialize the meditation player application
    #
    # Sets up all necessary components: audio player, state machine,
    # user interface, and state persistence.
    #
    # @return [App] new instance
    def initialize
      @player = AudioPlayer.new
      @state = PlayerState.new(@player)
      @tui = TUI.new(@state)
      @persistence = StatePersistence.new(@state)
    end

    # Run the meditation player application
    #
    # Loads the previous state, starts the user interface,
    # and saves the state when exiting.
    #
    # @return [void]
    def run
      @persistence.load
      begin
        @tui.run
      ensure
        @state.stop
        @persistence.save
      end
    end
  end
end