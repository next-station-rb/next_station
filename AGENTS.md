# Development Guidelines

This document defines the principles and conventions that should guide the development of this Ruby gem. The main goal is to produce code that is clean, readable, maintainable, and safe in concurrent environments, prioritizing long-term quality over short-term convenience.

## 0. What is the purpose of this gem?

> **Note:** This is just a high-level overview of the gem for reference. **Do not attempt to implement or write it from this description**—it’s meant to explain what the gem does, not how to build it.

NextStation is a lightweight, thread-safe toolkit for building Railway Oriented Programming (ROP) style operations in Ruby. It helps decouple business logic from controllers/models in both plain Ruby and Rails apps (without depending on Rails).

- Clean, SOLID-friendly DSL for defining operations and steps
- Immutable context, isolated operation state
- Explicit success/failure results with typed, localized errors
- Validations (dry-validation) and Results (dry-struct) integration
- Step controls: conditional skip, retries, and minimal branching
- Dependency Injection
- Plugins system with hook points (includes JSON Logging via semantic_logger)
- Introspection via class config helpers

## 1. Design Principles

### SOLID as a foundation
The application of SOLID principles should be favored whenever it is reasonable:

- Single Responsibility Principle (SRP)  
  Each class or module should have one clear responsibility.
- Open/Closed Principle (OCP)  
  Code should be open for extension but closed for modification.
- Liskov Substitution Principle (LSP)  
  Subtypes must be substitutable for their base types without unexpected behavior.
- Interface Segregation Principle (ISP)  
  Prefer small, focused interfaces over large, generic ones.
- Dependency Inversion Principle (DIP)  
  Depend on abstractions, not on concrete implementations.

SOLID principles are guidelines, not rigid rules.
Avoid forcing abstractions when they introduce unnecessary complexity, excessive nesting of files or directories, or an explosion of tiny classes.

## 2. Readability and Simplicity

- Code readability is a top priority.
- Prefer explicit and easy-to-understand code over clever or overly compact solutions.
- A new developer should be able to quickly understand the intent of the code.
- Use clear and descriptive names for classes, methods, and variables.
- Avoid comments that explain what the code does; the code should be self-explanatory.  
  Comments should explain why a decision was made when it is not obvious.

## 3. RuboCop Conventions

- Code should follow RuboCop conventions as the general standard.
- Breaking a RuboCop rule is acceptable when:
    - Following it introduces unnecessary complexity.
    - It significantly harms readability.
    - It forces unnatural or artificial code structures.

In such cases:
- The decision must be deliberate and justified.
- Prefer disabling rules locally (`# rubocop:disable`) rather than globally.
- Briefly document the reason when it is not obvious.

## 4. Thread Safety

The gem must be thread-safe by default, considering usage in concurrent environments.

Expected best practices:

- Avoid mutable global state.
- Do not use class variables (`@@`) unless strictly necessary and proven safe.
- Prefer immutable objects.
- Properly synchronize access to shared resources when required.
- Be cautious with memoization in concurrent contexts.

## 5. Framework-Agnostic Design (Rails Optional)

This gem is intended to be usable both in Rails and non-Rails environments.

Guidelines:

- Do not introduce dependencies that force users to install Rails-related gems.
- Avoid relying on Rails-specific libraries such as ActiveSupport, ActiveModel, etc.
- Use plain Ruby alternatives whenever possible.
- If Rails-specific integrations are needed, they should be:
    - Optional
    - Clearly isolated
    - Loaded conditionally

The core functionality of the gem must remain framework-agnostic.

## 6. Code Structure

- Maintain a clear and consistent organization of files and modules.
- Modules should reflect the domain and intent of the code.
- Avoid oversized classes; split responsibilities when appropriate.
- Favor composition over inheritance.

## 7. Runtime Optimization (YJIT and JRuby)
This gem should be written with performance considerations for both **CRuby (with YJIT enabled)** and **JRuby**, without sacrificing readability or maintainability.

### YJIT Considerations (CRuby)
When writing code intended to benefit from YJIT:

- Avoid using OpenStruct
- Avoid redefining basic integer operations (i.e. +, -, <, >, etc.)
- Avoid redefining the meaning of nil, equality, etc.
- Avoid allocating objects in the hot parts of your code
- Minimize layers of indirection
- Avoid writing wrapper classes if you can (e.g. a class that only wraps a Ruby hash)
- Avoid methods that just call another method
- Ruby method calls are costly. Avoid things such as methods that only return a value from a hash

### JRuby Considerations

When targeting JRuby compatibility and performance:

- Avoid Ruby features with poor JVM performance characteristics (e.g., heavy use of `eval`).
- Prefer long-lived objects over frequent short-lived allocations when reasonable.
- Be mindful of object churn in hot paths.
- Avoid relying on MRI-specific behavior or undocumented internals.
- Ensure all code is compatible with JRuby’s threading and concurrency model.

## 8. Documentation Consistency

- Any functional or behavioral change must be reflected in the documentation.
- The README must be updated to stay in sync with the current behavior and API of the gem.
- Examples, usage instructions, and configuration options should accurately reflect the current implementation.
- Avoid specs that require excessive setup or deep object graphs.


## 9. RSpec Style and Structure

- Use `describe` for classes and modules.
- Use `context` to describe meaningful state or conditions.
- Use `it` blocks with clear, descriptive sentences.
- Prefer `let` over instance variables.
- Avoid excessive use of `before(:all)`; prefer `before(:each)`.
### Modification of existing specs:
If new behavior requires additional coverage:
- Add new test files or new examples.
- Test modifications are allowed only when they are strictly necessary to support new or explicitly requested functionality.

### Do NOT touch the human-generated specs.
- IMPORTANT: Files under `spec/contract/` are immutable and must never be modified by you.

### Ignore result of human-generated specs.
Spec under `spec/contract/` may fail as you do not control this. You must ignore the results of these specs.
- When running rspec or scpec commands, you can find a way to exclude those files during your test run.


## 10. Pragmatism

- These guidelines exist to improve the codebase, not to slow down development.
- When in doubt, choose and prefer the solution that is:
    1. More readable
    2. Simpler
    3. Easier to maintain in the long term
- Dont forget to update the README.