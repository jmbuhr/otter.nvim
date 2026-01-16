.PHONY: test test-file clean

# Run all tests
test:
	@./tests/run

# Run a specific test file (usage: make test-file FILE=tests/core/otter_spec.lua)
test-file:
	@./tests/run $(FILE)

# Clean test artifacts
clean:
	rm -rf .tests/
