#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../lib/meditation_player"

module MeditationPlayer
  # Performance monitoring tools for testing CPU usage and identifying leaks
  class PerformanceMonitor
    def initialize
      @samples = []
      @monitoring = false
    end

    # Monitor CPU usage for the given block
    def monitor_cpu(duration_seconds = 10)
      start_time = Time.now
      process_pid = Process.pid
      cpu_samples = []

      # Start monitoring in background thread
      monitor_thread = Thread.new do
        while Time.now - start_time < duration_seconds
          current_cpu_usage = cpu_usage(process_pid)
          cpu_samples << { time: Time.now, cpu: current_cpu_usage }
          sleep 0.5
        end
      end

      # Execute the block
      yield if block_given?

      # Wait for monitoring to complete
      monitor_thread.join

      # Calculate statistics
      avg_cpu = cpu_samples.sum { |s| s[:cpu] } / cpu_samples.size.to_f
      max_cpu = cpu_samples.map { |s| s[:cpu] }.max
      min_cpu = cpu_samples.map { |s| s[:cpu] }.min

      {
        duration: duration_seconds,
        sample_count: cpu_samples.size,
        average_cpu: avg_cpu,
        max_cpu: max_cpu,
        min_cpu: min_cpu,
        samples: cpu_samples
      }
    end

    # Test idle CPU usage
    def test_idle_cpu(duration_seconds = 10)
      puts "Testing idle CPU usage for #{duration_seconds} seconds..."
      puts "Starting meditation player in background..."

      # Start player in background process
      player_pid = fork do
        player = MeditationPlayer::App.new
        player.run
      end

      # Wait a moment for player to start
      sleep 2

      begin
        results = monitor_cpu(duration_seconds)
        puts "\n=== IDLE CPU USAGE RESULTS ==="
        puts "Duration: #{results[:duration]}s"
        puts "Samples: #{results[:sample_count]}"
        puts "Average CPU: #{results[:average_cpu].round(2)}%"
        puts "Max CPU: #{results[:max_cpu].round(2)}%"
        puts "Min CPU: #{results[:min_cpu].round(2)}%"
        puts "\nHigh CPU warning!" if results[:average_cpu] > 20
        results
      ensure
        # Clean up
        Process.kill("TERM", player_pid) if player_pid
        Process.wait(player_pid) if player_pid
      end
    end

    # Test CPU usage during playback
    def test_playback_cpu(duration_seconds = 30)
      puts "Testing playback CPU usage for #{duration_seconds} seconds..."

      # Start player in background process
      player_pid = fork do
        player = MeditationPlayer::App.new
        player.run
      end

      # Wait for player to start
      sleep 2

      begin
        puts "Starting playback test..."
        results = monitor_cpu(duration_seconds)
        puts "\n=== PLAYBACK CPU USAGE RESULTS ==="
        puts "Duration: #{results[:duration]}s"
        puts "Samples: #{results[:sample_count]}"
        puts "Average CPU: #{results[:average_cpu].round(2)}%"
        puts "Max CPU: #{results[:max_cpu].round(2)}%"
        puts "Min CPU: #{results[:min_cpu].round(2)}%"
        results
      ensure
        # Clean up
        Process.kill("TERM", player_pid) if player_pid
        Process.wait(player_pid) if player_pid
      end
    end

    private

    # Get CPU usage for a process (macOS/Linux)
    def cpu_usage(pid)
      output = `ps -p #{pid} -o %cpu 2>/dev/null | tail -n 1`.strip
      output.to_f
    rescue StandardError
      0.0
    end
  end
end

# Run performance tests if this file is executed directly
if __FILE__ == $PROGRAM_NAME
  monitor = MeditationPlayer::PerformanceMonitor.new

  puts "=== CPU PERFORMANCE TESTS ==="
  puts "Testing meditation player CPU usage..."

  # Test idle usage
  monitor.test_idle_cpu(10)

  puts "\n#{'=' * 50}\n"

  # Test playback usage if audio files exist
  audio_files = Dir.glob(File.join(__dir__, "..", "audio_files", "*.{mp3,mp4,wav,ogg}"))
  if audio_files.any?
    monitor.test_playback_cpu(15)
  else
    puts "No audio files found. Skipping playback test."
    puts "To test playback, add audio files to the audio_files/ directory."
  end

  puts "\n=== TEST COMPLETE ==="
end
