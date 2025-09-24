# frozen_string_literal: true

module MeditationPlayer
  # Audio playback controller using ffplay
  # Handles audio file operations and process management
  #
  # This module manages audio file discovery, playback control, and process management
  # for meditation audio files. It interfaces with the ffplay command-line tool.
  #
  # @author Your Name
  # @since 1.0.0
  class AudioPlayer
    # Directory containing audio files
    AUDIO_DIR = File.join(__dir__, "..", "audio_files").freeze

    # Initialize a new audio player
    #
    # @return [AudioPlayer] new instance
    def initialize
      @process = nil
      @current_file = nil
      @paused = false
      @start_time = nil
      @pause_time = nil
      @file_durations = {}
    end

    # Get list of available audio files
    #
    # @return [Array<String>] array of audio file paths
    def audio_files
      @audio_files ||= Dir.glob(File.join(AUDIO_DIR, "*.{mp3,mp4,wav,ogg}"))
    end

    # Play the specified audio file
    #
    # @param file_path [String] path to audio file
    # @return [void]
    def play(file_path)
      return unless File.exist?(file_path)

      stop if playing?
      @current_file = file_path
      @start_time = Time.now
      @paused = false
      @process = spawn("ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", file_path,
                       :pgroup => true, %i[out err] => "/dev/null")
    end

    # Stop currently playing audio
    #
    # @return [Float] the percentage of the file that was played (0.0 to 1.0)
    def stop
      return 0.0 unless @process

      progress = calculate_progress
      begin
        Process.kill("-TERM", -@process)
      rescue Errno::ESRCH
        # Process already terminated
      end
      @process = nil
      @current_file = nil
      @start_time = nil
      @paused = false
      progress
    end

    # Check if audio is currently playing
    #
    # @return [Boolean] true if playing, false otherwise
    def playing?
      @process && Process.waitpid(@process, Process::WNOHANG).nil? && !@paused
    rescue Errno::ESRCH
      false
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

      begin
        Process.kill("-STOP", -@process)
        @pause_time = Time.now
        @paused = true
      rescue Errno::ESRCH
        # Process already terminated
      end
    end

    # Resume paused audio
    #
    # @return [void]
    def resume
      return unless paused?

      begin
        # Adjust start time to account for pause duration
        pause_duration = Time.now - @pause_time
        @start_time += pause_duration
        @pause_time = nil

        Process.kill("-CONT", -@process)
        @paused = false
      rescue Errno::ESRCH
        # Process already terminated
      end
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
      calculate_progress if @current_file && @start_time
    end

    private

    # Calculate the current playback progress
    #
    # @return [Float] progress percentage (0.0 to 1.0)
    def calculate_progress
      return 0.0 unless @current_file && @start_time

      duration = get_file_duration(@current_file)
      return 0.0 if duration <= 0

      elapsed = if paused?
                  # If paused, use the time when pause was initiated
                  @pause_time - @start_time
                else
                  Time.now - @start_time
                end

      progress = elapsed / duration
      [progress, 1.0].min # Cap at 1.0 (100%)
    end

    # Get the duration of an audio file in seconds
    #
    # @param file_path [String] path to audio file
    # @return [Float] duration in seconds
    def get_file_duration(file_path)
      @file_durations[file_path] ||= begin
        output = `ffprobe -v quiet -show_entries format=duration -of csv=p=0 "#{file_path}" \
                   2>/dev/null`
        output.strip.to_f
      rescue StandardError
        0.0
      end
    end
  end
end
