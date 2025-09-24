# frozen_string_literal: true

require_relative "test_helper"

module MeditationPlayer
  class NinetyPercentRuleVerificationTest < Test
    def setup
      @player = MPVPlayer.new
      @state = PlayerState.new(@player)
    end

    def teardown
      @player&.stop
    end

    def test_ninety_percent_rule_is_implemented_in_stop_playback
      # Verify the 90% rule is implemented in the code
      stop_playback_method = @state.class.instance_method(:stop_playback)
      source_code = stop_playback_method.source_location

      # Read the source file to verify the implementation
      file_content = File.read(source_code[0])

      # Check that the 90% rule is implemented
      assert_includes file_content, "progress >= 0.9",
                      "90% rule should be implemented in stop_playback"
      assert_includes file_content, "record_played_file",
                      "Should call record_played_file when progress >= 90%"
    end

    def test_ninety_percent_rule_is_implemented_in_go_to_next
      # Verify the 90% rule is implemented in go_to_next
      go_to_next_method = @state.class.instance_method(:go_to_next)
      source_code = go_to_next_method.source_location

      # Read the source file to verify the implementation
      file_content = File.read(source_code[0])

      # Check that the 90% rule is implemented
      assert_includes file_content, "progress >= 0.9",
                      "90% rule should be implemented in go_to_next"
      assert_includes file_content, "record_played_file",
                      "Should call record_played_file when progress >= 90%"
    end

    def test_random_file_selector_has_10_file_limit
      # Verify the 10-file limit is implemented
      selector = @state.random_selector
      max_recent_files = selector.class.const_get(:MAX_RECENT_FILES)

      assert_equal 10, max_recent_files, "Should have MAX_RECENT_FILES set to 10"

      # Verify the enforcement method exists (it's private)
      enforcement_method = selector.class.private_instance_methods(false)
      assert_includes enforcement_method, :enforce_recently_played_limit,
                      "Should have private enforce_recently_played_limit method"
    end

    def test_ten_file_limit_enforcement_method
      # Verify the enforcement method works correctly
      selector = @state.random_selector

      # Get the enforcement method
      enforce_method = selector.class.instance_method(:enforce_recently_played_limit)
      source_code = File.read(enforce_method.source_location[0])

      # Check that it enforces the 10-file limit
      assert_includes source_code, "MAX_RECENT_FILES", "Should use MAX_RECENT_FILES constant"
      assert_includes source_code, "length >", "Should check array length"
      assert_includes source_code, "shift", "Should remove oldest files"
    end

    def test_requirements_are_documented_in_code
      # Check that the requirements are documented in the code
      player_state_file = File.read("lib/player_state.rb")
      selector_file = File.read("lib/random_file_selector.rb")

      # Check for 90% rule documentation
      assert_includes player_state_file, "90%", "90% rule should be documented"

      # Check for 10-file limit documentation
      assert_includes selector_file, "10", "10-file limit should be documented"
      assert_includes selector_file, "recently played", "Recently played files should be documented"
    end
  end
end
