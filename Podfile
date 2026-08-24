platform :ios, '17.0'

inhibit_all_warnings!

target 'MotionNote' do
  pod 'AFNetworking', :git => 'https://github.com/AFNetworking/AFNetworking.git', :tag => '4.0.1'
  pod 'Masonry', :git => 'https://github.com/SnapKit/Masonry.git', :tag => 'v1.1.0'
  pod 'Mantle', :podspec => 'Podspecs/Mantle.podspec'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
      if target.name == 'AFNetworking'
        config.build_settings['CLANG_ENABLE_MODULES'] = 'NO'
        config.build_settings['CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES'] = 'YES'
      end
    end
  end
end
