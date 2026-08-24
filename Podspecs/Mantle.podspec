Pod::Spec.new do |spec|
  spec.name = 'Mantle'
  spec.version = '2.2.0'
  spec.summary = 'Model framework for Cocoa and Cocoa Touch.'
  spec.homepage = 'https://github.com/Mantle/Mantle'
  spec.license = { :type => 'MIT', :file => 'LICENSE.md' }
  spec.authors = 'Mantle Contributors'
  spec.source = { :git => 'https://github.com/Mantle/Mantle.git', :tag => '2.2.0' }
  spec.platform = :ios, '9.0'
  spec.requires_arc = true
  spec.framework = 'Foundation'
  spec.source_files = 'Mantle/**/*.{h,m}'
  spec.public_header_files = 'Mantle/include/*.h', 'Mantle/extobjc/include/*.h'
end
