# CLAUDE.md

## Development Principles

- **TDD Approach**: Always write tests first, then implement functionality. Ensure all tests pass before considering a feature complete.
- **Documentation**: Document what requires context or has complex logic. Avoid self-evident method documentation (e.g., "Get filename of current file"). Focus on:
  - Complex business logic and algorithms
  - Architectural decisions and patterns
  - Non-obvious behavior or side effects
  - Configuration and setup requirements
  - Error handling and edge cases
- **KISS/YAGNI**: Follow Keep It Simple, Stupid and You Ain't Gonna Need It principles. Avoid over-engineering.
- **DRY**: Follow Don't Repeat Yourself principle. Avoid duplicating code, logic, or configuration. Extract common functionality into reusable components.
- **Minimal Code**: Strive for ultra-minimal solutions. The less code, the better. Remove any unnecessary complexity.
- **Resource Management**: In tests, ensure all started processes or playing audio files are properly stopped/cleaned up to prevent resource leaks.

## Commands

### Running the Application
```bash
bin/mindfu
```

### Testing
```bash

# Run all tests
find tests -name "*_test.rb" -exec ruby -Ilib {} \;
ruby -Ilib tests/*_test.rb

# Run specific test file
ruby -Ilib tests/unit/mpv_player_test.rb
ruby -Ilib tests/unit/player_state_test.rb
ruby -Ilib tests/integration/mpv_player_integration_test.rb
ruby -Ilib tests/feature/playback_completion_test.rb

# Run tests by category
ruby -Ilib tests/unit/*_test.rb          # Unit tests
ruby -Ilib tests/integration/*_test.rb   # Integration tests
ruby -Ilib tests/feature/*_test.rb      # Feature tests

# Run tests with test helper
ruby -Ilib tests/test_helper.rb

# Run performance tests (in separate directory)
find tests/performance_tests -name "*.rb" -exec ruby -Ilib {} \;
ruby -Ilib tests/performance_tests/performance_test.rb
ruby -Ilib tests/performance_tests/tui_cpu_test.rb
ruby -Ilib tests/performance_tests/test_idle_specific.rb
ruby -Ilib tests/performance_tests/verify_fix.rb

# Run Rubocop on all tests
bundle exec rubocop tests/
bundle exec rubocop tests/unit/
bundle exec rubocop tests/integration/
bundle exec rubocop tests/feature/
bundle exec rubocop tests/performance_tests/
```

### Testing Strategy

Tests focus on:
- State machine transitions and event handling
- Process management (mocked for test safety)
- State persistence and restoration
- Component integration
- Performance and CPU usage monitoring

Performance tests specifically focus on:
- CPU usage optimization in TUI main loop
- Idle state performance
- Memory usage patterns
- Process cleanup verification

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

## Documentation Style

### What to Document:
- **Complex algorithms**: e.g., random file selection excluding recently played files
- **State machine transitions**: Event-driven behavior and side effects
- **Process lifecycle**: MPV process spawning, monitoring, and cleanup
- **Database schema evolution**: Backward compatibility and column additions
- **IPC protocol**: JSON command structure and response handling
- **Error boundaries**: How failures are handled and propagated

### What NOT to Document:
- Simple getter methods (e.g., `current_file`, `audio_files`)
- Obvious navigation methods (e.g., `next`, `previous`)
- Basic control methods (e.g., `play`, `pause`, `stop`)
- Self-evident return values or parameters
- One-liner methods with clear implementation

### Documentation Guidelines:
- **Class-level documentation**: Explain the purpose, responsibilities, and key patterns
- **Method-level documentation**: Only for complex logic, non-obvious behavior, or public APIs with side effects
- **Comments**: Use inline comments to explain "why" not "what" - especially for business rules or tricky algorithms

### Documentation Examples:
```ruby
# GOOD: Documents complex logic and business rules
def random_index
  return 0 if audio_files.empty?

  # Get recently played filenames (last 10)
  recent_files = get_recently_played_filenames(10)

  # Find available files not in recent history
  available_indices = []
  audio_files.each_with_index do |file_path, index|
    filename = File.basename(file_path)
    available_indices << index unless recent_files.include?(filename)
  end

  # Fall back to random if all files are recent
  available_indices.empty? ? rand(audio_files.length) : available_indices.sample
end

# BAD: Self-evident getter
# Get the filename of current audio file
# @return [String, nil] filename or nil if not playing
def current_filename
  current_file ? File.basename(current_file) : nil
end
```

## Architecture

The meditation player follows a modular architecture with clear separation of concerns:

### Core Components

1. **MPVPlayer** (`lib/mpv_player.rb`): Handles mpv process management
   - Uses JSON IPC for accurate progress tracking and control
   - Manages process groups for proper cleanup
   - Redirects output to `/dev/null` for background operation
   - Supports proper pause/resume through mpv commands

2. **PlayerState** (`lib/player_state.rb`): State machine using `state_machines` gem
   - Manages transitions between :stopped, :playing, :paused states
   - Handles file navigation (next/previous track)
   - Triggers appropriate MPVPlayer methods during state transitions
   - Includes random file selection functionality

3. **TUI** (`lib/tui.rb`): Terminal user interface using curses
   - Minimal interface showing current file and playback state
   - Handles keyboard input for controls
   - No progress bar (removed for simplicity)

### Key Design Patterns

- **State Machine**: Central to controlling playback behavior
- **Dependency Injection**: Components are loosely coupled through constructor injection
- **Process Management**: Proper Unix signal handling for audio playback
- **Error Handling**: Graceful degradation when mpv processes fail
- **IPC Communication**: JSON-based Inter-Process Communication for accurate progress tracking

### Keyboard Controls

#### English Layout
- `SPACE`: Play/Pause toggle
- `S`: Stop playback
- `N`: Next track
- `P`: Previous track
- `Q`: Quit application

### State Machine Events

The player responds to these events:
- `play`: Start playback from stopped state or resume from paused
- `pause`: Pause currently playing audio
- `resume`: Resume from paused state
- `stop`: Stop playback and return to stopped state
- `next`/`previous`: Navigate between tracks

### Process Management

mpv runs in background process groups with:
- `--no-video`: No video display
- `--autoexit`: Process terminates when playback completes
- `--loglevel=quiet`: Suppress console output
- `--input-ipc-server=SOCKET`: JSON IPC communication socket
- Output redirected to `/dev/null`
- Proper cleanup on application exit

