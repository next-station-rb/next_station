# frozen_string_literal: true

require_relative 'lib/next_station/version'

Gem::Specification.new do |spec|
  spec.name          = 'next_station'
  spec.version       = NextStation::VERSION
  spec.authors       = ['Hugo Vilchis']
  spec.email = ['havilchis@users.noreply.github.com']

  spec.summary = 'A lightweight, flexible framework for building service objects (Operations) in Ruby'
  spec.homepage = 'https://github.com/next-station-rb/next_station'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 3.0.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/next-station-rb/next_station'
  spec.metadata['changelog_uri'] = 'https://github.com/next-station-rb/next_station/releases'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # Uncomment to register a new dependency of your gem
  spec.add_dependency 'dry-struct', '~> 1'
  spec.add_dependency 'dry-types', '~> 1'
  spec.add_dependency 'dry-validation', '~> 1'
  spec.add_dependency 'dry-configurable', '~> 1'
  spec.add_dependency 'dry-monitor', '~> 1'

  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'debase' unless ENV['SKIP_DEBASE_GEM']
  spec.add_development_dependency 'ruby-debug-ide' unless ENV['SKIP_RUBY_DEBUG_IDE_GEM']

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
