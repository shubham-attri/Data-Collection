platform :ios, '15.0'

target 'Data-Collection' do
  use_frameworks!
  
  # Nordic Libraries
  pod 'iOSMcuManager'
  pod 'iOS-BLE-Library'
  
  # Testing
  target 'Data-CollectionTests' do
    inherit! :search_paths
    pod 'iOS-BLE-Library-Mock'
  end
end 