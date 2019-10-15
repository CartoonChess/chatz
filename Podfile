# Uncomment the next line to define a global platform for your project
platform :ios, '11.0'

target 'chatz' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for Flash Chat

  # add the Firebase pod for Google Analytics
  pod 'Firebase/Analytics'
  # add pods for any other desired Firebase products
  # https://firebase.google.com/docs/ios/setup#available-pods
  pod 'Firebase/Auth'
  pod 'Firebase/Database'
  # We're using Firestore instead of database (must silence warnings due to Protobug issue)
  pod 'Firebase/Firestore', :inhibit_warnings => true
  # Deal with Protobuf capitalization warnings (dependency in Firebase/Firestore)
  pod 'FirebaseFirestore', :inhibit_warnings => true
  # Is Messaging also throwing Protobuf warnings?
  pod 'Firebase/Messaging', :inhibit_warnings => true
  # Extra line here again...
  pod 'FirebaseMessaging', :inhibit_warnings => true
  pod 'Protobuf', :inhibit_warnings => true

  # others
  # Tutorial wants SVProgressHUD - we'll use a similar one
  pod 'JGProgressHUD'
  # ChameleonFramework - colours
  # SwiftJSON - should we use this too?

end
