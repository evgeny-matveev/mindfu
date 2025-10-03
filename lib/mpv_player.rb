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
  # @author Yevgeny Matveyev
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
      @completion_callback = nil
      @monitor_thread = nil
      @progress_callback = nil
      @last_progress_percentage = 0
    end

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
      @mpv_socket = "/tmp/mpvsocket_#{@mpv_socket}"
      @mpv_pid = spawn("mpv", "--no-video", "--input-ipc-server=#{@mpv_socket}", file_path,
                       :pgroup => true, %i[out err] => "/dev/null")
      @current_file = file_path
      @playing = true
      @paused = false

      # Start monitoring playback events
      start_playback_monitoring
    end

    def stop
      terminate_mpv_process
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

    def pause
      return unless playing?

      send_command("set_property", "pause", true)
      @paused = true
    end

    def resume
      return unless paused?

      send_command("set_property", "pause", false)
      @paused = false
    end

    def current_file
      @current_file ? File.basename(@current_file) : nil
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

      # Stop monitoring thread
      @monitor_thread&.kill
      @monitor_thread = nil
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

    # Set completion callback
    #
    # Sets a callback to be invoked when playback completes naturally.
    #
    # @param callback [Proc] callback procedure to invoke on completion
    # @return [void]
    #
    # @example Set completion callback
    #   player.set_completion_callback(-> { puts "Playback completed!" })
    public

    def set_completion_callback(&callback)
      @completion_callback = callback
    end

    # Set progress callback
    #
    # Sets a callback to be invoked when playback reaches certain percentages.
    #
    # @param callback [Proc] callback procedure to invoke with progress info
    # @return [void]
    #
    # @example Set progress callback
    #   player.set_progress_callback { |percentage| puts "Progress: #{percentage}%" }
    def set_progress_callback(&callback)
      @progress_callback = callback
    end

    # Check if playback is completed
    #
    # @return [Boolean] true if playback has reached the end, false otherwise
    def playback_completed?
      return false unless @mpv_socket

      # Check if playback has reached the end
      time_pos = get_mpv_property("time-pos")
      duration = get_mpv_property("duration")

      time_pos && duration && time_pos >= duration
    end

    # Get current playback position
    #
    # @return [Float, nil] current playback position in seconds, or nil if not playing
    def current_position
      get_mpv_property("time-pos")
    end

    # Get total duration
    #
    # @return [Float, nil] total duration in seconds, or nil if not available
    def total_duration
      get_mpv_property("duration")
    end

    private

    # Start monitoring playback events
    #
    # @return [void]
    def start_playback_monitoring
      return if @monitor_thread&.alive?

      @monitor_thread = Thread.new do
        loop do
          break unless @mpv_pid && @mpv_socket

          # Check if playback has completed naturally
          if playback_completed?
            @playing = false
            @paused = false
            @completion_callback&.call
            break
          end

          # Track progress and call callback at 50% threshold
          if @progress_callback && @playing && !@paused
            current_pos = current_position
            total_dur = total_duration

            if current_pos && total_dur && total_dur.positive?
              percentage = (current_pos / total_dur * 100).to_i

              # Call callback at 50% threshold only
              if percentage >= 50 && @last_progress_percentage < 50
                @progress_callback.call(50)
                @last_progress_percentage = 50
              end
            end
          end

          # Check if process is still running
          unless mpv_process_running?
            @playing = false
            @paused = false
            break
          end

          sleep 0.5 # Check every half second
        end
      end
    end
  end
end
