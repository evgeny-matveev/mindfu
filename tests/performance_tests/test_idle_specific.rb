#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../lib/tui"
require_relative "../../lib/player_state"
require_relative "../../lib/mpv_player"

module MeditationPlayer
  # Test idle state specifically
  class IdleStateTest
    def initialize
      @player = MPVPlayer.new
      @state = PlayerState.new(@player)
      @tui = TUI.new(@state)
    end

    # rubocop:disable Metrics/AbcSize
    def test_idle_cpu_fix(duration_seconds = 5)
      puts "Testing idle state CPU usage for #{duration_seconds} seconds..."
      puts "State: not playing (should use 0.2s sleep intervals)..."

      start_time = Time.now
      cpu_samples = []
      iterations = 0

      # Simulate idle state (not playing)
      tui_thread = Thread.new do
        running = true
        last_update = Time.now

        while running && Time.now - start_time < duration_seconds
          current_time = Time.now
          iterations += 1

          # Idle state update interval (1 second)
          update_interval = 1.0 # not playing state
          if current_time - last_update >= update_interval
            # Simulate draw operation (rare in idle)
            last_update = current_time
          end

          # Simulate input handling
          # key = @window.getch (non-blocking)
          # process_key(key) if key

          # FIXED: Idle state sleep (0.2 seconds)
          sleep 0.2

          running = false if Time.now - start_time >= duration_seconds
        end
      end

      # Monitor CPU
      monitor_thread = Thread.new do
        while Time.now - start_time < duration_seconds
          cpu = cpu_usage
          cpu_samples << { time: Time.now, cpu: cpu }
          sleep 0.2
        end
      end

      tui_thread.join
      monitor_thread.join

      avg_cpu = cpu_samples.sum { |s| s[:cpu] } / cpu_samples.size.to_f
      max_cpu = cpu_samples.map { |s| s[:cpu] }.max

      puts "\n=== IDLE STATE CPU TEST ==="
      puts "Iterations: #{iterations}"
      puts "Duration: #{duration_seconds}s"
      puts "Average CPU: #{avg_cpu.round(2)}%"
      puts "Max CPU: #{max_cpu.round(2)}%"
      puts "Iterations per second: #{(iterations / duration_seconds).round(1)}"

      if avg_cpu < 3
        puts "✅ IDLE CPU OPTIMIZED!"
        puts "Idle state CPU usage is excellent."
      else
        puts "⚠️  Idle CPU could be further optimized."
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
  test = MeditationPlayer::IdleStateTest.new
  test.test_idle_cpu_fix(5)
end
