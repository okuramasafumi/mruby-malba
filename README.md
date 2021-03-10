[![CI](https://github.com/okuramasafumi/mruby-malba/actions/workflows/main.yml/badge.svg?branch=main)](https://github.com/okuramasafumi/mruby-malba/actions/workflows/main.yml)

# mruby-malba

Malba is a JSON serializer for mruby.

## install by mrbgems
- add conf.gem line to `build_config.rb`

```ruby
MRuby::Build.new do |conf|

    # ... (snip) ...

    conf.gem :github => 'okuramasafumi/mruby-malba'
end
```

## License
under the MIT License:
- see LICENSE file
