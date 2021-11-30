# react-native-yookassa-payments

###### iOS NATIVE SDK - 6.0.0
###### Android NATIVE SDK - 6.0.1

`npm install react-native-yookassa-payments --save`

### Android installation:

1.  Create `libs` folder in `android/app` directory and put there `ThreatMetrix Android SDK 5.4-73.aar` file (this file will given you by yookassa manager)
2.  Add folowing lines in dependencies `android/build.gradle`

```java
allprojects {
    repositories {
        mavenCentral()
    }
}
```

3.  Add folowing lines in dependencies `android/app/build.gradle`

```java
dependencies {
    implementation "ru.yoomoney.sdk.auth:auth:1.2.8"
}
```

4.  In `android/app/build.gradle` file add next dependency

```java
dependencies {
    implementation fileTree(dir: "libs", include: ["*.aar"])
}
```

5.  Also important to add your app scheme. In `android/app/build.gradle` add following lines:

```java
android {
    defaultConfig {
        resValue "string", "ym_app_scheme", "your_unique_app_scheme"
    }
}
```

6. Add this in AndroidManifest.xml for card scanning work

```java
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
<uses-feature android:name="android.hardware.camera.flash" android:required="false" />
```

### iOS installation:

1.  Change Podfile like this:

```
source 'https://cdn.cocoapods.org/'
source 'https://github.com/yoomoney-tech/cocoa-pod-specs.git'
plugin 'cocoapods-user-defined-build-types',  {
  verbose: true
}
enable_user_defined_build_types!

platform :ios, '10.0'

target 'YourAppName' do
  config = use_native_modules!

  pod 'react-native-yookassa-payments', :path => '../node_modules/react-native-yookassa-payments'
   
  pod 'CardIO' 
   
  pod 'YooKassaPayments',
      :build_type => :dynamic_framework,
      :git => 'https://github.com/yoomoney/yookassa-payments-swift.git',
      :tag => '6.0.0'
  end
```

2.  Add TMXProfiling.xcframework and TMXProfilingConnections.xcframework to ios/Frameworks using Finder or other file manager 
3.  Add TMXProfiling.xcframework and TMXProfilingConnections.xcframework to Frameworks, Libraries, and Embedded Content in Xcode Project
4.  Add Foundation.swift using Xcode in root folder (ios/Foundation.swift) and select "Сreate Bridging Header"
5.  `pod install`
6. (Optional) Russian Localization
    - In your Xcode project => Info => Localization => Click "+" => Add Russian language
    - Copy everything from ios/yookassa-payments-swift-6.0.0/YooKassaPayments/Public/Resources/ru.lproj/Localizable.strings
    - In your Xcode project => File => New File => Strings File => Localizable.strings => Open new created Localizable.strings and paste all copy strings
    - After pasting strings look at Xcode right side and find a Localization menu => Choose Russian language 

### P.S
If you see errors in Xcode Project like this:
```
Failed to build module 'MoneyAuth' from its module interface...
Compipiling for iOS 10.0, but module 'FunctiionalSwift' has a minimum deployment target iOS 11.0...
Typedef redefinition with different types ('uint8_t' (aka 'unsigned char'))...
```
You can resolve it by adding post_install in your Podfile:
```
post_install do |installer|
  installer.pods_project.targets.each do |target|
  target.build_configurations.each do |config|
  if target.name == 'FunctionalSwift' || target.name == 'YooMoneyCoreApi'
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '10.0'
  else
  if target.name == 'RCT-Folly'
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '9.0'
  else
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '12.0'
                    end
                end
            end
        end
    end
end
```
https://github.com/yoomoney/yookassa-payments-swift/issues/93

For using your custom realization of 3DSecure confirmation, specify returnUrl: string for redirect to your link. Not use confirmPayment() method with returnUrl.  

