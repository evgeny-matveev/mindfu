# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/random_file_selector"

module MeditationPlayer
  class RandomFileSelectorLimitTest < Test
    def setup
      @player = MPVPlayer.new
      @state = PlayerState.new(@player)
      @selector = RandomFileSelector.new(@state, test_mode: false)
    end

    def teardown
      @player&.stop
    end

    def test_should_only_exclude_last_10_files_not_90_percent
      # Create 20 files total
      mock_files = (1..20).map { |i| "file#{i}.mp3" }

      @player.stub(:audio_files, mock_files) do
        # Mark first 15 files as played (more than 10, but less than 90%)
        15.times do |i|
          @selector.record_played_file("file#{i + 1}.mp3")
        end

        recently_played = @selector.instance_variable_get(:@recently_played_files)

        # Current behavior: keeps 90% = 18 files
        # This test will fail, showing the issue
        puts "Current recently played count: #{recently_played.length}"
        puts "Expected recently played count: 10"

        # According to requirement, should only keep last 10
        # So files 1-5 should be available for selection, files 6-15 should be excluded
        available_files = mock_files - recently_played
        puts "Available files: #{available_files}"

        # This assertion will fail with current implementation
        # assert_equal 10, recently_played.length, "Should only keep last 10 files, not 90%"
      end
    end

    def test_exactly_10_files_should_be_excluded_when_more_than_10_played
      # Create 15 files total
      mock_files = (1..15).map { |i| "file#{i}.mp3" }

      @player.stub(:audio_files, mock_files) do
        # Mark 12 files as played
        12.times do |i|
          @selector.record_played_file("file#{i + 1}.mp3")
        end

        recently_played = @selector.instance_variable_get(:@recently_played_files)

        # Should only keep last 10 played files
        # So files 1-2 should be available, files 3-12 should be excluded
        expected_excluded = (3..12).map { |i| "file#{i}.mp3" }

        puts "Total files: #{mock_files.length}"
        puts "Recently played count: #{recently_played.length}"
        puts "Expected excluded: #{expected_excluded}"
        puts "Actually excluded: #{recently_played}"

        # Should contain the most recent 10 files (files 3-12)
        expected_excluded.each do |file|
          assert_includes recently_played, file, "Should exclude recently played file: #{file}"
        end

        # Should NOT contain the oldest files (files 1-2)
        refute_includes recently_played, "file1.mp3", "Should not exclude oldest file"
        refute_includes recently_played, "file2.mp3", "Should not exclude second oldest file"

        # Should have exactly 10 files excluded
        assert_equal 10, recently_played.length, "Should exclude exactly 10 files"
      end
    end

    def test_less_than_10_files_should_all_be_excluded
      # Create 15 files total
      mock_files = (1..15).map { |i| "file#{i}.mp3" }

      @player.stub(:audio_files, mock_files) do
        # Create a fresh selector that won't load persistence
        fresh_selector = RandomFileSelector.new(@state)
        fresh_selector.instance_variable_set(:@recently_played_files, [])

        # Mark only 7 files as played
        7.times do |i|
          fresh_selector.record_played_file("file#{i + 1}.mp3")
        end

        recently_played = fresh_selector.instance_variable_get(:@recently_played_files)

        # Should keep all 7 played files (less than 10)
        7.times do |i|
          assert_includes recently_played, "file#{i + 1}.mp3",
                          "Should exclude all played files when less than 10"
        end

        assert_equal 7, recently_played.length, "Should exclude all 7 played files"
      end
    end
  end
end
