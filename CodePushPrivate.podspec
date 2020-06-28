
Pod::Spec.new do |spec|

  spec.name         = "CodePushPrivate"
  spec.version      = "0.0.1"
  spec.summary      = "CodePushPrivate."
  spec.description  = <<-DESC
                      RN 热更新组件
                   DESC
  spec.homepage     = "https://github.com/yongqianvip/CodePushPrivate"

  spec.license      = "MIT"

  spec.author             = { "yongqianvip" => "yongqianvip@163.com" }

  spec.platform     = :ios
  spec.platform     = :ios, "9.0"

  spec.source       = { :git => "https://github.com/yongqianvip/CodePushPrivate.git", :tag => "#{spec.version}" }

  spec.source_files  = "CodePushPrivate/Classes/**/*.{h,m}"

  spec.dependency 'AFNetworking', '~> 4.0.1'
  spec.dependency 'SSZipArchive', '~> 2.2.3'
end
