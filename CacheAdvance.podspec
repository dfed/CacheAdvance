Pod::Spec.new do |s|
  s.name     = 'CacheAdvance'
  s.version  = '1.2.4'
  s.license  = 'Apache License, Version 2.0'
  s.summary  = 'A performant cache for logging systems. CacheAdvance persists log events 30x faster than SQLite.'
  s.homepage = 'https://github.com/dfed/CacheAdvance'
  s.authors  = 'Dan Federman'
  s.source   = { :git => 'https://github.com/dfed/CacheAdvance.git', :tag => s.version }
  s.swift_version = '5.1'
  s.source_files = 'Sources/**/*.{swift}', 'Sources/**/*.{h,m}'
  s.ios.deployment_target = '12.0'
  s.tvos.deployment_target = '12.0'
  s.watchos.deployment_target = '5.0'
  s.macos.deployment_target = '10.14'
end
