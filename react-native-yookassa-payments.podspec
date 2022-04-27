
Pod::Spec.new do |s|
  s.name         = "react-native-yookassa-payments"
  s.version      = "1.0.0"
  s.summary      = "YooKassa Payments component"
  s.description  = <<-DESC
                  YooKassa Payments component
                   DESC
  s.homepage     = "https://gitlab.com/getgain-public/libs/react-native-yookassa-payments.git"
  s.license      = "MIT"
  s.author             = { "author" => "author@domain.cn" }
  s.platform     = :ios, "10.0"
  s.source       = { :git => "https://gitlab.com/getgain-public/libs/react-native-yookassa-payments.git", :tag => "master" }
  s.source_files  = "ios/*"
  s.requires_arc = true


  s.dependency "React"
  s.dependency "YooKassaPayments"

end

