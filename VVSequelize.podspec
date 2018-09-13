Pod::Spec.new do |s|
  s.name             = 'VVSequelize'
  s.version          = '0.3.0'
  s.summary          = '基于FMDB的ORM模型封装.'
  s.description      = <<-DESC
                       基于FMDB的ORM模型封装.
                       DESC
  s.homepage         = 'https://github.com/pozi119/VVSequelize'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Valo Lee' => 'pozi119@163.com' }
  s.source           = { :git => 'https://github.com/pozi119/VVSequelize.git', :tag => s.version.to_s }
  s.ios.deployment_target = '8.0'
  
  s.default_subspec = 'standard'
  
  s.source_files = "VVSequelize/**/*"

  s.subspec 'standard' do |ss|
      ss.dependency "FMDB"
  end
  
  s.subspec 'fts' do |ss|
      ss.dependency "FMDB/FTS"
  end

end


