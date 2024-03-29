#
# Be sure to run `pod lib lint FLMediaLibrary.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'FLMediaLibrary'
  s.version          = '0.1.9'
  s.summary          = '播放器，图片浏览器'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  封装播放器，图片浏览器
                       DESC
                       
  s.homepage         = 'https://github.com/weijiewen/FLMediaLibrary'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'weijiewen' => 'txywjw@icloud.com' }
  s.source           = { :git => 'https://github.com/weijiewen/FLMediaLibrary.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '9.0'

  s.source_files = 'FLMediaLibrary/Classes/**/*'
  
  # s.resource_bundles = {
  #   'FLMediaLibrary' => ['FLMediaLibrary/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  s.frameworks = 'AVFoundation'
  # s.dependency 'AFNetworking', '~> 2.3'
end
