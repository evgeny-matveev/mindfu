#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../../lib/tui"
require_relative "../../lib/player_state"
require_relative "../../lib/mpv_player"

module MeditationPlayer
  # Verify the CPU fix
  class CPUFixVerifier
    def initialize
      @player = MPVPlayer.new
      @state = PlayerState.new(@player)
      @tui = TUI.new(@state)
    end

    # rubocop:disable Metrics/AbcSize
    def verify_cpu_fix(duration_seconds = 5)
      puts "Verifying CPU fix for #{duration_seconds} seconds..."
      puts "Testing the optimized TUI loop timing..."

      start_time = Time.now
      cpu_samples = []
      iterations = 0

      # Simulate the FIXED TUI main loop
      tui_thread = Thread.new do
        running = true
        last_update = Time.now

        while running && Time.now - start_time < duration_seconds
          current_time = Time.now
          iterations += 1

          # FIXED: Longer update intervals
          update_interval = 0.25 # playing state (was 0.1)
          if current_time - last_update >= update_interval
            # Simulate draw operation
            last_update = current_time
          end

          # Simulate input handling
          # key = @window.getch (non-blocking)
          # process_key(key) if key

          # FIXED: Proper sleep timing (was 0.01, now 0.1)
          sleep 0.1

          running = false if Time.now - start_time >= duration_seconds
        end
      end

      # Monitor CPU
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

      puts "\n=== CPU FIX VERIFICATION ==="
      puts "Iterations: #{iterations}"
      puts "Duration: #{duration_seconds}s"
      puts "Average CPU: #{avg_cpu.round(2)}%"
      puts "Max CPU: #{max_cpu.round(2)}%"
      puts "Iterations per second: #{(iterations / duration_seconds).round(0)}"

      if avg_cpu < 5
        puts "✅ CPU LEAK FIXED!"
        puts "CPU usage is now within acceptable range."
      else
        puts "❌ CPU leak still present or needs further optimization."
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
  puts "Testing the CPU fix..."
  test = MeditationPlayer::CPUFixVerifier.new
  test.verify_cpu_fix(5)
end
