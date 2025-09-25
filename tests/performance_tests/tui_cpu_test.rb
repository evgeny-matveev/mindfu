#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../lib/tui"
require_relative "../../lib/player_state"
require_relative "../../lib/mpv_player"

module MeditationPlayer
  # Direct TUI CPU test to isolate the issue
  class TUIPerformanceTest
    def initialize
      @player = MPVPlayer.new
      @state = PlayerState.new(@player)
      @tui = TUI.new(@state)
    end

    # rubocop:disable Metrics/AbcSize
    def test_cpu_usage(duration_seconds = 5)
      puts "Testing TUI CPU usage for #{duration_seconds} seconds..."
      puts "This test will simulate the TUI loop without curses..."

      start_time = Time.now
      cpu_samples = []
      iterations = 0

      # Simulate the TUI main loop without curses
      tui_thread = Thread.new do
        running = true
        last_update = Time.now

        while running && Time.now - start_time < duration_seconds
          current_time = Time.now
          iterations += 1

          # Simulate the update intervals from TUI
          update_interval = 0.1 # playing state
          if current_time - last_update >= update_interval
            # Simulate draw operation
            last_update = current_time
          end

          # Simulate input handling - this is the potential CPU leak
          # Original code:
          # @window.nodelay = true
          # key = @window.getch
          # @window.nodelay = false
          # process_key(key) if key
          # sleep 0.05  # Only when not playing

          # The issue: minimal sleep only in some states
          sleep 0.01 # Simulate minimal sleep

          running = false if Time.now - start_time >= duration_seconds
        end
      end

      # Monitor CPU in main thread
      monitor_thread = Thread.new do
        while Time.now - start_time < duration_seconds
          cpu = cpu_usage
          cpu_samples << { time: Time.now, cpu: cpu }
          sleep 0.1
        end
      end

      tui_thread.join
      monitor_thread.join

      avg_cpu = cpu_samples.sum { |s| s[:cpu] } / cpu_samples.size.to_f
      max_cpu = cpu_samples.map { |s| s[:cpu] }.max

      puts "\n=== TUI CPU TEST RESULTS ==="
      puts "Iterations: #{iterations}"
      puts "Duration: #{duration_seconds}s"
      puts "Average CPU: #{avg_cpu.round(2)}%"
      puts "Max CPU: #{max_cpu.round(2)}%"
      puts "Iterations per second: #{(iterations / duration_seconds).round(0)}"

      if avg_cpu > 10
        puts "⚠️  HIGH CPU USAGE DETECTED!"
        puts "This indicates a CPU leak in the TUI loop."
      end

      { avg_cpu: avg_cpu, max_cpu: max_cpu, iterations: iterations }
    end
    # rubocop:enable Metrics/AbcSize

    private

    def cpu_usage
      pid = Process.pid
      output = `ps -p #{pid} -o %cpu 2>/dev/null | tail -n 1`.strip
      output.to_f
    rescue StandardError
      0.0
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  test = MeditationPlayer::TUIPerformanceTest.new
  test.test_cpu_usage(5)
end
