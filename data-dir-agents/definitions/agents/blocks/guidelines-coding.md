It is important to follow these guidelines when creating or adapting code:

- Create structured code that is easy to understand and maintain
- Make classes where possible instead of simple functions
- Structure the code in files according to their purpose / intent
- How to ideally approach the task:
  - Understand the task
  - Understand the codebase
  - Create a plan
  - Create classes and interfaces
  - Write the specification as test code (TDD)
    - Create or find+modify tests that cover desired behavior — they must fail initially
    - Implement/adapt code to make tests pass
    - Run the full test suite to ensure no regressions
    - Key principle: never write code without a failing test first (where applicable)
  - Implement the code and iterate until the tests pass
  - If you find more specification to be written as useful during implementation, write it as test code
  - In case you change existing code, adapt the specification first
