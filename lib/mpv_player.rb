# frozen_string_literal: true

require "json"
require "socket"

module MeditationPlayer
  # Audio playback controller using mpv
  # Handles audio file operations and process management
  #
  # This module manages audio file discovery, playback control, and process management
  # for meditation audio files. It interfaces with the mpv command-line tool.
  # This implementation uses JSON IPC for accurate progress tracking and control.
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
      @mpv_socket = nil
      @current_file = nil
      @playing = false
      @paused = false
      @file_durations = {}
      @completion_callback = nil
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
      spawn_mpv(file_path)
    end

    # Spawn mpv process with IPC socket
    #
    # @param file_path [String] path to audio file
    # @return [void]
    def spawn_mpv(file_path)
      @mpv_socket = "/tmp/mpvsocket_#{object_id}"
      @mpv_pid = spawn("mpv", "--no-video", "--input-ipc-server=#{@mpv_socket}", file_path,
                       :pgroup => true, %i[out err] => "/dev/null")
      @current_file = file_path
      @playing = true
      @paused = false
    end

    # Stop currently playing audio
    #
    # @return [Float] the percentage of the file that was played (0.0 to 1.0)
    def stop
      progress = current_progress
      terminate_mpv_process
      progress
    end

    # Check if audio is currently playing
    #
    # @return [Boolean] true if playing, false otherwise
    def playing?
      @playing && !@paused
    end

    # Check if audio is currently paused
    #
    # @return [Boolean] true if paused, false otherwise
    def paused?
      @paused
    end

    # Pause currently playing audio
    #
    # @return [void]
    def pause
      return unless playing?

      send_command("set_property", "pause", true)
      @paused = true
    end

    # Resume paused audio
    #
    # @return [void]
    def resume
      return unless paused?

      send_command("set_property", "pause", false)
      @paused = false
    end

    # Get the filename of currently playing audio
    #
    # @return [String, nil] filename or nil if not playing
    def current_file
      @current_file ? File.basename(@current_file) : nil
    end

    # Get the current playback progress as a percentage
    #
    # @return [Float] progress percentage (0.0 to 1.0)
    def current_progress
      return 0.0 unless @mpv_socket

      begin
        time_pos = get_mpv_property("time-pos")
        duration = get_mpv_property("duration")

        return 0.0 if time_pos.nil? || duration.nil? || duration.to_f <= 0

        progress = time_pos.to_f / duration
        [progress, 1.0].min # Cap at 1.0 (100%)
      rescue StandardError
        0.0
      end
    end

    # Set callback for when playback completes naturally
    #
    # @param callback [Proc] callback to execute when playback completes
    # @return [void]
    def on_completion(&callback)
      @completion_callback = callback
    end

    # Check if playback has completed naturally
    #
    # @return [Boolean] true if mpv process has terminated naturally
    def playback_completed?
      return false unless @mpv_pid && @playing

      !process_running?(@mpv_pid)
    end

    # Check for completion and trigger callback if needed
    #
    # @return [void]
    def check_completion
      return unless playback_completed?

      # Get progress before cleanup
      progress = current_progress

      # Clean up the process
      terminate_mpv_process

      # Trigger completion callback with progress
      @completion_callback&.call(progress)
    end

    # Send command to mpv via IPC
    #
    # @param command [String] mpv command
    # @param args [Array] command arguments
    # @return [Hash, nil] response from mpv
    def send_command(command, *args)
      return nil unless @mpv_socket

      begin
        socket = UNIXSocket.new(@mpv_socket)
        request = { "command" => [command] + args }.to_json
        socket.puts(request)
        response = socket.gets
        socket.close

        response ? JSON.parse(response) : nil
      rescue StandardError
        nil
      end
    end

    private

    # Terminate mpv process and clean up
    #
    # @return [void]
    def terminate_mpv_process
      return unless @mpv_pid

      # Try to terminate the process gracefully
      begin
        Process.kill("TERM", @mpv_pid)

        # Wait for graceful termination
        10.times do
          break unless process_running?(@mpv_pid)

          sleep 0.1
        end

        # Force kill if still running
        Process.kill("KILL", @mpv_pid) if process_running?(@mpv_pid)
      rescue Errno::ESRCH
        # Process already terminated
      end

      # Clean up socket file
      if @mpv_socket && File.exist?(@mpv_socket)
        begin
          File.delete(@mpv_socket)
        rescue Errno::ENOENT
          # Socket already deleted
        end
      end

      @mpv_pid = nil
      @mpv_socket = nil
      @current_file = nil
      @playing = false
      @paused = false
    end

    # Check if a specific process is running
    #
    # @param pid [Integer] process ID to check
    # @return [Boolean] true if running, false otherwise
    def process_running?(pid)
      Process.kill(0, pid)
      true
    rescue Errno::ESRCH
      false
    end

    # Check if mpv process is running
    #
    # @return [Boolean] true if running, false otherwise
    def mpv_process_running?
      return false unless @mpv_pid

      begin
        Process.waitpid(@mpv_pid, Process::WNOHANG).nil?
      rescue Errno::ESRCH
        false
      end
    end

    # Get property from mpv
    #
    # @param property [String] property name
    # @return [Object, nil] property value
    def get_mpv_property(property)
      response = send_command("get_property", property)
      response && response["data"]
    end
  end
end
