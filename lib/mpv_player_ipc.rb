# frozen_string_literal: true

module MeditationPlayer
  # Audio playback controller using mpv
  # Handles audio file operations and process management via JSON IPC
  #
  # This module manages audio file discovery, playback control, and process management
  # for meditation audio files. It interfaces with the mpv command-line tool using
  # JSON IPC for precise progress tracking and control.
  #
  # @author Your Name
  # @since 2.0.0
  class MPVPlayer
    # Directory containing audio files
    AUDIO_DIR = File.join(__dir__, "..", "audio_files").freeze

    # Initialize a new mpv audio player
    #
    # @return [MPVPlayer] new instance
    def initialize
      @mpv_pid = nil
      @current_file = nil
      @mpv_socket = nil
      @paused = false
    end

    # Get list of available audio files
    #
    # @return [Array<String>] array of audio file paths
    def audio_files
      @audio_files ||= Dir.glob(File.join(AUDIO_DIR, "*.{mp3,mp4,wav,ogg}"))
    end

    # Play the specified audio file using mpv
    #
    # @param file_path [String] path to audio file
    # @return [void]
    def play(file_path)
      return unless File.exist?(file_path)

      stop if playing?
      @current_file = file_path
      @paused = false
      spawn_mpv(file_path)
    end

    # Stop currently playing audio
    #
    # @return [Float] the percentage of the file that was played (0.0 to 1.0)
    def stop
      return 0.0 unless @mpv_pid

      progress = current_progress
      terminate_mpv_process
      progress
    end

    # Check if audio is currently playing
    #
    # @return [Boolean] true if playing, false otherwise
    def playing?
      @mpv_pid && mpv_process_running? && !@paused
    end

    # Check if audio is currently paused
    #
    # @return [Boolean] true if paused, false otherwise
    def paused?
      @paused
    end

    # Pause currently playing audio using mpv properties
    #
    # @return [void]
    def pause
      return unless playing?

      begin
        send_command("set_property", "pause", true)
        @paused = true
      rescue StandardError
        # Fallback to terminating process if IPC fails
        terminate_mpv_process
      end
    end

    # Resume paused audio using mpv properties
    #
    # @return [void]
    def resume
      return unless paused?

      begin
        send_command("set_property", "pause", false)
        @paused = false
      rescue StandardError
        # If IPC fails, reset state
        terminate_mpv_process
      end
    end

    # Get the filename of currently playing audio
    #
    # @return [String, nil] filename or nil if not playing
    def current_file
      @current_file ? File.basename(@current_file) : nil
    end

    # Get the current playback progress as a percentage via mpv IPC
    #
    # @return [Float] progress percentage (0.0 to 1.0)
    def current_progress
      return 0.0 unless @mpv_pid && @mpv_socket

      begin
        time_pos = get_mpv_property("time-pos")
        duration = get_mpv_property("duration")

        if time_pos && duration&.positive?
          progress = time_pos.to_f / duration
          [progress, 1.0].min # Cap at 1.0 (100%)
        else
          0.0
        end
      rescue StandardError
        0.0
      end
    end

    private

    # Spawn mpv process with JSON IPC socket
    #
    # @param file_path [String] path to audio file
    # @return [void]
    def spawn_mpv(file_path)
      require "securerandom"
      @mpv_socket = "/tmp/mpvsocket_#{SecureRandom.hex(8)}"

      cmd = [
        "mpv",
        "--no-video",
        "--input-ipc-server=#{@mpv_socket}",
        "--pause", # Start paused to prevent playback before IPC connection
        "--autoexit",
        "--loglevel=quiet",
        file_path
      ]

      @mpv_pid = spawn(*cmd, :pgroup => true, %i[out err] => "/dev/null")

      # Wait a moment for the socket to be created
      sleep 0.1

      # Start playback
      send_command("set_property", "pause", false)
    end

    # Terminate mpv process and clean up resources
    #
    # @return [void]
    def terminate_mpv_process
      return unless @mpv_pid

      begin
        Process.kill("-TERM", -@mpv_pid)
      rescue Errno::ESRCH
        # Process already terminated
      end

      @mpv_pid = nil
      @current_file = nil
      @paused = false

      # Clean up socket file
      File.delete(@mpv_socket) if @mpv_socket && File.exist?(@mpv_socket)
      @mpv_socket = nil
    end

    # Check if mpv process is still running
    #
    # @return [Boolean] true if process is running
    def mpv_process_running?
      return false unless @mpv_pid

      Process.waitpid(@mpv_pid, Process::WNOHANG).nil?
    rescue Errno::ESRCH
      false
    end

    # Send a command to mpv via JSON IPC
    #
    # @param command [String] mpv command
    # @param args [Array] command arguments
    # @return [Hash, nil] parsed response or nil on error
    def send_command(command, *args)
      return nil unless @mpv_socket

      begin
        require "socket"
        require "json"

        UNIXSocket.open(@mpv_socket) do |socket|
          request = { "command" => [command] + args }.to_json
          socket.puts(request)
          response = socket.gets
          JSON.parse(response) if response
        end
      rescue StandardError
        nil
      end
    end

    # Get a property value from mpv
    #
    # @param property [String] property name
    # @return [Object, nil] property value or nil on error
    def get_mpv_property(property)
      response = send_command("get_property", property)
      response&.dig("data")
    end
  end
end
