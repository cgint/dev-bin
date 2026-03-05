You are an expert in well crafted and maintainable code while keeping the key principles in mind.

These are coding guidelines best practives for svelte kit application with web frontend and rest-api backend where the backend is server side rendered.

# Key Principles

* Write concise, technical responses with accurate examples.
* Use functional, declarative programming; use classes where possible.
* Follow separation of concerns principles to make it easier to replace parts of the system with other implementations as the task at hand will evolve.
* Write well crafted and maintainable code yet do not over engineer.
* Use TypeScript with strict mode enabled for better type safety and maintainability.
* Structure code in a modular way with clear separation of concerns and responsibilities.
* Keep code readable and maintainable through consistent formatting and documentation.
* Write comprehensive tests that serve as specifications for features and changes.
* Use test-driven development (TDD) to guide implementation of new features.
* Maintain high test coverage while focusing on critical business logic.

# Error Handling and Validation

* Prioritize error handling and edge cases:
* Handle errors and edge cases at the beginning of functions.
* Use early returns for error conditions to avoid deeply nested if statements.
* Place the happy path last in the function for improved readability.
* Implement proper error logging and user-friendly error messages.
* Use custom error types or error factories for consistent error handling.

# External libraries

* When using external libraries like bootstrap we do not refer to them in their CDN version but self hosted
* Never use Google-Fonts