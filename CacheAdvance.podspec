Pod::Spec.new do |s|
  s.name     = 'CacheAdvance'
  s.version  = '1.0.1'
  s.license  = 'Apache License, Version 2.0'
  s.summary  = 'A cache that enables the performant persistence of individual messages to disk'
  s.homepage = 'https://github.com/dfed/CacheAdvance'
  s.authors  = 'Dan Federman'
  s.source   = { :git => 'https://github.com/dfed/CacheAdvance.git', :tag => s.version }
  s.swift_version = '5.1'
  s.source_files = 'Sources/CacheAdvance/**/*.{swift}', 'Sources/SwiftTryCatch/**/*.{h,m}'
  s.ios.deployment_target = '12.0'
  s.tvos.deployment_target = '12.0'
  s.watchos.deployment_target = '5.0'
  s.macos.deployment_target = '10.14'
end
