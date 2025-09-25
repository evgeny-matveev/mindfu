### Testing
```bash

# Run all tests
find tests -name "*_test.rb" -exec ruby -Ilib {} \;
ruby -Ilib tests/*_test.rb

# Run specific test file
ruby -Ilib tests/mpv_player_test.rb
ruby -Ilib tests/player_state_test.rb
ruby -Ilib tests/random_file_selector_test.rb

# Run tests with test helper
ruby -Ilib tests/test_helper.rb
```

### Testing Strategy

Tests focus on:
- State machine transitions and event handling
- Process management (mocked for test safety)
- State persistence and restoration
- Component integration

All tests use Minitest and follow a functional approach with minimal mocking.

### Code Quality
```bash
# Run Rubocop linting
bundle exec rubocop

# Run Rubocop with auto-correction
bundle exec rubocop -A
```

### Documentation
```bash
# Generate YARD documentation
bundle exec yard
```