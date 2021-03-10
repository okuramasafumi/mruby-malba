MRuby::Gem::Specification.new('mruby-malba') do |spec|
  spec.license = 'MIT'
  spec.authors = 'OKURA Masafumi'

  spec.add_dependency 'mruby-metaprog'
  spec.add_dependency 'mruby-hash-ext'
  spec.add_dependency 'mruby-json'
  spec.add_dependency 'mruby-object-ext'
  spec.add_dependency 'mruby-class-ext'

  # Test
  spec.add_dependency 'mruby-proc-ext'
  spec.add_dependency 'mruby-print'
end
