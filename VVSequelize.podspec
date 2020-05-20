
Pod::Spec.new do |s|
  s.name             = 'VVSequelize'
  s.version          = '0.3.1-beta6'
  s.summary          = 'ORM model based on SQLite3.'
  s.description      = <<-DESC
                       ORM model based on SQLite3.
                       DESC

  s.homepage         = 'https://github.com/pozi119/VVSequelize'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Valo Lee' => 'pozi119@163.com' }
  s.source           = { :git => 'https://github.com/pozi119/VVSequelize.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'
  s.default_subspec = 'cipher'
  
  s.subspec 'system' do |ss|
      ss.dependency 'VVSequelize/common'
      ss.libraries = 'sqlite3'
  end
  
  s.subspec 'cipher' do |ss|
      ss.dependency 'VVSequelize/common'
      ss.dependency 'SQLCipher'
      ss.pod_target_xcconfig = {
          'OTHER_CFLAGS' => '$(inherited) -DSQLITE_HAS_CODEC -DHAVE_USLEEP=1',
          'HEADER_SEARCH_PATHS' => "{PODS_ROOT}/SQLCipher"
      }
  end

  s.subspec 'common' do |ss|
      ss.source_files = 'VVSequelize/Classes/**/*'
      ss.public_header_files = 'VVSequelize/Classes/**/*.h'
      ss.resource = ['VVSequelize/Assets/VVPinYin.bundle']
  end

end
