require 'json'

module MeditationPlayer
  # Handles saving and loading player state to/from JSON files
  # Preserves current file index and state between sessions
  #
  # This class provides persistence for the player's state, allowing
  # users to resume their session between application runs.
  #
  # @author Your Name
  # @since 1.0.0
  class StatePersistence
    # Path to the state file
    STATE_FILE = File.join(__dir__, '..', 'player_state.json').freeze

    # Initialize state persistence with player state
    #
    # @param state [PlayerState] the player state to persist
    # @return [StatePersistence] new instance
    def initialize(state)
      @state = state
    end

    # Save current player state to JSON file
    #
    # Saves the current index, state, and timestamp to the state file.
    # Handles errors gracefully without interrupting the application.
    #
    # @return [void]
    def save
      data = {
        current_index: @state.current_index,
        state: @state.state.to_s,
        timestamp: Time.now.iso8601
      }

      File.write(STATE_FILE, JSON.pretty_generate(data))
    rescue StandardError => e
      warn "Failed to save state: #{e.message}"
    end

    # Load player state from JSON file
    #
    # Restores the previous session state if available. Handles errors
    # gracefully without interrupting the application.
    #
    # @return [void]
    def load
      return unless File.exist?(STATE_FILE)

      data = JSON.parse(File.read(STATE_FILE))
      @state.instance_variable_set(:@current_index, data['current_index'] || 0)

      state_name = data['state'] || 'stopped'
      # Set state through the appropriate event
      case state_name
      when 'playing'
        @state.play unless @state.playing?
      when 'paused'
        @state.play
        @state.pause unless @state.paused?
      when 'stopped'
        @state.stop unless @state.state.to_s == 'stopped'
      end
    rescue StandardError => e
      warn "Failed to load state: #{e.message}"
    end
  end
end