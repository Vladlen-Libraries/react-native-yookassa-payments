# react-native-yookassa-payments

<a href="https://www.npmjs.com/package/react-native-yookassa-payments"><img src="https://github.com/npm/logos/blob/master/npm%20logo/classic/npm-2009.png" height="32" width="64" ></a>

###### iOS NATIVE SDK - 6.7.0
###### Android NATIVE SDK - 6.4.0

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

3. In `android/app/build.gradle` file add next dependency

```java
dependencies {
    implementation fileTree(dir: "libs", include: ["*.aar"])
}
```

4. Also important to add your app scheme. In `android/app/build.gradle` add following lines:

```java
android {
    defaultConfig {
        resValue "string", "ym_app_scheme", "your_unique_app_scheme"
    }
}
```

5. Add this in AndroidManifest.xml for card scanning work

```java
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false" />
<uses-feature android:name="android.hardware.camera.flash" android:required="false" />
```

### iOS installation:

1.  Change Podfile like this:

```
source 'https://git.yoomoney.ru/scm/sdk/cocoa-pod-specs.git'
source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '10.0'

target 'YourAppName' do
  config = use_native_modules!

  pod 'react-native-yookassa-payments', :path => '../node_modules/react-native-yookassa-payments'
   
  pod 'CardIO' 
   
  pod 'YooKassaPayments',
      :build_type => :dynamic_framework,
      :git => 'https://git.yoomoney.ru/scm/sdk/yookassa-payments-swift.git',
      :tag => '6.7.0'
```
2. Add Foundation.swift using Xcode in root folder (ios/Foundation.swift) and select "Сreate Bridging Header"
3. `pod install`
4. (Optional) Russian Localization
    - In your Xcode project => Info => Localization => Click "+" => Add Russian language
    - Copy everything from ios/yookassa-payments-swift-6.1.1/YooKassaPayments/Public/Resources/ru.lproj/Localizable.strings
    - In your Xcode project => File => New File => Strings File => Localizable.strings => Open new created Localizable.strings and paste all copy strings
    - After pasting strings look at Xcode right side and find a Localization menu => Choose Russian language

### Google Pay
For testing Google Pay and approve Business Console screenshots
```
await YooPayment.pay({
   //add this line
   testMode: 1,    
});
```

### Apple Pay
Specify merchantId for apple pay integration
```
await YooPayment.pay({
  //add this line
  applePayMerchantIdentifier: "merchant.com.your_app_name" 
});
```

### Custom 3DSecure confirmation 
For using your custom realization of 3DSecure confirmation, specify returnUrl: string for redirect to your link. Not use confirmPayment() method with returnUrl. 


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

