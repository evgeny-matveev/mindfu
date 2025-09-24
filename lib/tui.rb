# frozen_string_literal: true

require "curses"

module MeditationPlayer
  # Terminal user interface for meditation player
  # Displays current file and playback controls
  #
  # This class provides a text-based user interface using the curses library.
  # It displays the current playing file, playback state, and keyboard controls
  # for user interaction.
  #
  # @author Your Name
  # @since 1.0.0
  class TUI
    # Initialize TUI with player state
    #
    # @param state [PlayerState] the player state to display
    # @return [TUI] new instance
    def initialize(state)
      @state = state
      @window = nil
      @running = false
    end

    # Run the TUI application
    #
    # This method initializes the curses interface and enters the main loop
    # for handling user input and displaying the interface.
    #
    # @return [void]
    def run
      init_curses
      @running = true

      while @running
        draw
        handle_input
        sleep(0.1)
      end

      close_curses
    rescue StandardError => e
      close_curses
      raise e
    end

    private

    # Initialize curses interface
    #
    # Sets up the curses library for terminal UI with no cursor,
    # no echo, and keypad enabled.
    #
    # @return [void]
    def init_curses
      Curses.init_screen
      Curses.curs_set(0)
      Curses.noecho
      Curses.stdscr.keypad(true)
      @window = Curses.stdscr
    end

    # Close curses interface
    #
    # Properly closes the curses screen and restores terminal state.
    #
    # @return [void]
    def close_curses
      Curses.close_screen if Curses.stdscr
    end

    # Draw the complete user interface
    #
    # Clears the screen and draws all UI components:
    # header, status, controls, and footer.
    #
    # @return [void]
    def draw
      @window.clear
      @window.refresh

      draw_header
      draw_status
      draw_controls
      draw_footer
    end

    # Draw the header with title
    #
    # Displays the application title centered at the top of the screen.
    #
    # @return [void]
    def draw_header
      title = "Meditation Player"
      @window.setpos(0, (Curses.cols - title.length) / 2)
      @window.addstr(title)
    end

    # Draw the status information
    #
    # Shows the current filename and playback state.
    #
    # @return [void]
    def draw_status
      filename = @state.current_filename || "No file"
      state = @state.state.to_s.upcase

      @window.setpos(2, 2)
      @window.addstr("File: #{filename}")
      @window.setpos(3, 2)
      @window.addstr("State: #{state}")
    end

    # Draw the control instructions
    #
    # Displays the available keyboard controls for the user.
    #
    # @return [void]
    def draw_controls
      controls = [
        "[SPACE] Play/Pause",
        "[S] Stop",
        "[N] Next",
        "[P] Previous",
        "[Q] Quit"
      ]

      @window.setpos(7, 2)
      controls.each_with_index do |control, i|
        @window.addstr(control)
        @window.setpos(7 + i, 2) if i < controls.length - 1
      end
    end

    # Draw the footer with quit instruction
    #
    # Shows a reminder at the bottom of the screen about how to quit.
    #
    # @return [void]
    def draw_footer
      @window.setpos(Curses.lines - 1, 0)
      @window.addstr("Press Q to quit")
    end

    # Handle keyboard input from user
    #
    # Processes keyboard input and triggers appropriate state machine events:
    # SPACE - Play/Pause toggle
    # S - Stop playback
    # N - Next track
    # P - Previous track
    # Q - Quit application
    #
    # @return [void]
    def handle_input
      case @window.getch
      when " "
        if @state.playing?
          @state.pause
        elsif @state.paused?
          @state.resume
        else
          @state.play
        end
      when "s", "S"
        @state.stop
      when "n", "N"
        @state.next
      when "p", "P"
        @state.previous
      when "q", "Q"
        @running = false
      end
    end
  end
end
