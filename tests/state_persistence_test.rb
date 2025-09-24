# frozen_string_literal: true

require_relative "test_helper"
require "json"
require "tempfile"

module MeditationPlayer
  class StatePersistenceTest < Test
    def setup
      @player = AudioPlayer.new
      @state = PlayerState.new(@player)
      @temp_file = Tempfile.new("player_state.json")
      @persistence = StatePersistence.new(@state)

      if StatePersistence.const_defined?(:STATE_FILE)
        StatePersistence.send(:remove_const,
                              :STATE_FILE)
      end
      StatePersistence.const_set(:STATE_FILE, @temp_file.path)
    end

    def teardown
      @temp_file.unlink
      @player&.stop
    end

    def test_save_creates_json_file
      @persistence.save
      assert_path_exists @temp_file.path
    end

    def test_save_includes_current_index
      @state.instance_variable_set(:@current_index, 5)
      @persistence.save

      data = JSON.parse(File.read(@temp_file.path))
      assert_equal 5, data["current_index"]
    end

    def test_load_restores_current_index
      data = { current_index: 3, state: "stopped" }
      File.write(@temp_file.path, JSON.generate(data))

      @persistence.load
      assert_equal 3, @state.current_index
    end

    def test_load_handles_missing_file
      @temp_file.unlink

      @persistence.load
      # Should not raise an exception
      # Test passes if no exception is raised
    end
  end
end
