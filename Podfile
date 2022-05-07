# Uncomment the next line to define a global platform for your project
platform :ios, '11.0'

target 'Messenger' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!
  
  #Firebase
  pod 'Firebase/Core'
  pod 'Firebase/Auth'
  pod 'Firebase/Database'
  pod 'Firebase/Storage'

  # Facebook
  pod 'FBSDKLoginKit'
  
  # Google
  pod 'GoogleSignIn'
  
  pod 'MessageKit'
  pod 'JGProgressHUD'
  pod 'RealmSwift'
  pod 'SDWebImage'
  
end

post_install do |pi|
    pi.pods_project.build_configurations.each do |config|
      config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
    end
    pi.pods_project.targets.each do |t|
      t.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '11.0'
      end
    end
end
