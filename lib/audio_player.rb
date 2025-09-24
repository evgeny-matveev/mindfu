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
    AUDIO_DIR = File.join(__dir__, '..', 'audio_files').freeze

    # Initialize a new audio player
    #
    # @return [AudioPlayer] new instance
    def initialize
      @process = nil
      @current_file = nil
      @paused = false
    end

    # Get list of available audio files
    #
    # @return [Array<String>] array of audio file paths
    def audio_files
      @audio_files ||= Dir.glob(File.join(AUDIO_DIR, '*.{mp3,mp4,wav,ogg}')).sort
    end

    # Play the specified audio file
    #
    # @param file_path [String] path to audio file
    # @return [void]
    def play(file_path)
      return unless File.exist?(file_path)

      stop if playing?
      @current_file = file_path
      @paused = false
      @process = spawn('ffplay', '-nodisp', '-autoexit', '-loglevel', 'quiet', file_path,
                        pgroup: true, [:out, :err] => '/dev/null')
    end

    # Stop currently playing audio
    #
    # @return [void]
    def stop
      return unless @process

      begin
        Process.kill('-TERM', -@process)
      rescue Errno::ESRCH
        # Process already terminated
      end
      @process = nil
      @current_file = nil
      @paused = false
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
        Process.kill('-STOP', -@process)
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
        Process.kill('-CONT', -@process)
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
  end
end