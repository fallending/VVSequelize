Pod::Spec.new do |s|
  s.name             = 'VVSequelize'
  s.version          = '0.1.2'
  s.summary          = '基于FMDB的ORM模型封装.'
  s.description      = <<-DESC
                       基于FMDB的ORM模型封装.
                       DESC
  s.homepage         = 'https://github.com/pozi119/VVSequelize'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Valo Lee' => 'pozi119@163.com' }
  s.source           = { :git => 'https://github.com/pozi119/VVSequelize.git', :tag => s.version.to_s }
  s.ios.deployment_target = '8.0'
  s.source_files     = 'VVSequelize/Classes/**/*'
  s.dependency "FMDB/SQLCipher"
end
