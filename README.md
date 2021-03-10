# mruby-malba   [![Build Status](https://travis-ci.org/okuramasafumi/mruby-malba.svg?branch=master)](https://travis-ci.org/okuramasafumi/mruby-malba)
Malba class
## install by mrbgems
- add conf.gem line to `build_config.rb`

```ruby
MRuby::Build.new do |conf|

    # ... (snip) ...

    conf.gem :github => 'okuramasafumi/mruby-malba'
end
```
## example
```ruby
p Malba.hi
#=> "hi!!"
t = Malba.new "hello"
p t.hello
#=> "hello"
p t.bye
#=> "hello bye"
```

## License
under the MIT License:
- see LICENSE file
