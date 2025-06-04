Pod::Spec.new do |s|
  s.name     = 'CacheAdvance'
  s.version  = '4.0.0'
  s.license  = 'Apache License, Version 2.0'
  s.summary  = 'A performant cache for logging systems. CacheAdvance persists log events 30x faster than SQLite.'
  s.homepage = 'https://github.com/dfed/CacheAdvance'
  s.authors  = 'Dan Federman'
  s.source   = { :git => 'https://github.com/dfed/CacheAdvance.git', :tag => s.version }
  s.source_files = 'Sources/**/*.{swift}'
  s.ios.deployment_target = '13.0'
  s.tvos.deployment_target = '13.0'
  s.watchos.deployment_target = '6.0'
  s.macos.deployment_target = '10.15'
  s.visionos.deployment_target = '1.0'
end
