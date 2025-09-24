# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"

module MeditationPlayer
  class FreshStartTest < Test
    def test_app_starts_with_fresh_random_file_each_session
      # Test that each new PlayerState instance starts with a fresh random file
      player = AudioPlayer.new

      # Clean up any existing persistence
      recently_played_file = "tmp/recently_played.json"
      FileUtils.rm_f(recently_played_file)

      # Create first session
      state1 = PlayerState.new(player)
      initial_index1 = state1.current_index

      # Create second session
      state2 = PlayerState.new(player)
      initial_index2 = state2.current_index

      # Both should have valid indices
      assert_operator initial_index1, :>=, 0
      assert_operator initial_index2, :>=, 0
      assert_operator initial_index1, :<, player.audio_files.length
      assert_operator initial_index2, :<, player.audio_files.length

      # Test that session history is fresh (empty except for initial file)
      assert_equal 1, state1.random_selector.session_history.length
      assert_equal 1, state2.random_selector.session_history.length

      # Test that recently played files are accumulated across sessions
      recently_played1 = state1.random_selector.instance_variable_get(:@recently_played_files)
      recently_played2 = state2.random_selector.instance_variable_get(:@recently_played_files)

      # Files are only added to recently played when they're completed (90% listened)
      # Since no files have been completed, both should be empty
      assert_equal 0, recently_played1.length
      assert_equal 0, recently_played2.length

      # Clean up
      FileUtils.rm_f(recently_played_file)
    end

    def test_no_player_state_persistence_file_created
      # Test that player_state.json is not created or used
      state_file = "player_state.json"

      # Ensure file doesn't exist
      FileUtils.rm_f(state_file)

      # Create and use a PlayerState
      player = AudioPlayer.new
      state = PlayerState.new(player)
      state.play if player.audio_files.any?
      state.stop

      # File should not be created
      refute_path_exists state_file, "player_state.json should not be created"
    end

    def test_only_recently_played_files_persisted
      # Test that only recently played files are persisted
      recently_played_file = "recently_played.json"

      # Clean up any existing file
      FileUtils.rm_f("tmp/recently_played.json")

      # Create first session and record some files
      player = AudioPlayer.new
      state1 = PlayerState.new(player)

      # Get initial recently played files (should be empty since no files completed)
      state1.random_selector.instance_variable_get(:@recently_played_files).dup

      # Simulate completing some files (90%+ listened)
      if player.audio_files.length >= 3
        state1.random_selector.record_played_file(player.audio_files[0])
        state1.random_selector.record_played_file(player.audio_files[1])
      end

      # Get the final recently played files from first session
      final_recently_played1 = state1.random_selector.instance_variable_get(:@recently_played_files)

      # Create second session (should load persisted recently played files)
      state2 = PlayerState.new(player)
      final_recently_played2 = state2.random_selector.instance_variable_get(:@recently_played_files)

      # Second session should have the same recently played files as first session
      # No new random file should be added to recently played on initialization
      assert_equal final_recently_played1.length, final_recently_played2.length
      final_recently_played1.each { |file| assert_includes final_recently_played2, file }

      # Clean up
      FileUtils.rm_f(recently_played_file)
    end
  end
end
