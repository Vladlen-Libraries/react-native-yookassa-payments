#import "RNYookassaPayments-Bridging-Header.h"

@interface RCT_EXTERN_MODULE(RNRYPaymentManager, RCTViewManager)
RCT_EXTERN_METHOD(pay:(NSDictionary *)info callbacker:(RCTResponseSenderBlock)callback)
RCT_EXTERN_METHOD(cancel)
RCT_EXTERN_METHOD(confirmPayment:(NSString *)url callbacker:(RCTResponseSenderBlock)callback)
@end
