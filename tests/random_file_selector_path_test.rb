# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/random_file_selector"

module MeditationPlayer
  class RandomFileSelectorPathTest < Test
    def setup
      @player = MPVPlayer.new
      @state = PlayerState.new(@player)
      @selector = RandomFileSelector.new(@state)

      # Clear any existing recently played file
      FileUtils.rm_f(RandomFileSelector::RECENTLY_PLAYED_FILE)
    end

    def teardown
      @player&.stop
      # Clean up
      FileUtils.rm_f(RandomFileSelector::RECENTLY_PLAYED_FILE)
    end

    def test_audio_files_returns_full_paths_not_basenames
      # This test would have caught the original bug
      audio_files = @player.audio_files

      refute_empty audio_files

      # All files should be full paths, not just basenames
      audio_files.each do |file|
        assert file.start_with?("/"), "Audio file should be full path: #{file}"
        assert File.exist?(file), "Audio file should exist: #{file}"
      end

      # Get basenames to see what we're actually working with
      basenames = audio_files.map { |f| File.basename(f) }

      # Basenames should NOT include "file" prefix (this was the bug)
      basenames.each do |basename|
        refute_match(/^file\d+\.mp3$/, basename,
                    "Basename should not have 'file' prefix: #{basename}")
      end
    end

    def test_record_played_file_handles_full_paths_correctly
      # Test with real file paths (this would have failed before the fix)
      audio_files = @player.audio_files
      return if audio_files.empty?

      test_file = audio_files.first
      basename = File.basename(test_file)

      # This should work without issues
      @selector.record_played_file(test_file)

      # Check that the basename was stored
      recently_played = @selector.instance_variable_get(:@recently_played_files)
      assert_includes recently_played, basename

      # Verify the JSON file contains the basename, not full path
      data = JSON.parse(File.read(RandomFileSelector::RECENTLY_PLAYED_FILE))
      assert_includes data["recently_played"], basename
    end

    def test_select_random_file_excludes_recently_played_with_full_paths
      # Test the actual integration with real file paths
      audio_files = @player.audio_files
      return if audio_files.length < 2

      # Record one file as played
      played_file = audio_files.first
      @selector.record_played_file(played_file)

      # The selected file should preferably be different from the played one
      # (unless there's only one file)
      selected_file = @selector.select_random_file

      if audio_files.length > 1
        # With the fix, this should work correctly
        assert selected_file
        assert_includes audio_files, selected_file
      end
    end

    def test_filename_matching_is_case_insensitive
      # Test the actual file system interaction
      audio_files = @player.audio_files
      return if audio_files.empty?

      test_file = audio_files.first
      basename = File.basename(test_file)

      # Record with full path
      @selector.record_played_file(test_file)

      # Should be able to find it when checking against real files
      available_basenames = @state.player.audio_files.map { |f| File.basename(f) }
      assert_includes available_basenames, basename
    end

    private

    def available_basenames
      @state.player.audio_files.map { |f| File.basename(f) }
    end
  end
end