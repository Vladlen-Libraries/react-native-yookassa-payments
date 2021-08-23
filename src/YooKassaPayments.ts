import { NativeModules } from "react-native";
import {
  PaymentConfig,
  PaymentInterface,
  PaymentResult,
  PaymentType,
} from "../index";

const RNRYPay = NativeModules.RNRYPaymentManager;

export default class RNRYPayment implements PaymentInterface {
  apiKey = undefined;
  testMode = 0;

  pay(info: PaymentConfig): Promise<PaymentResult> {
    return new Promise((resolve, reject) => {
      RNRYPay.pay(
        {
          api_key: this.apiKey,
          shop_name: info["shop_name"],
          shop_id: info["shop_id"],
          amount: info["amount"],
          purchase_description: info["purchase_description"],
          payment_types: info["payment_types"],
          test: this.testMode,
          applePayMerchantIdentifier: info["applePayMerchantIdentifier"],
        },
        (token: string, type: PaymentType, error: any) => {
          if (!!token && !!type) {
            resolve({
              token: token,
              type: type,
            });
          } else if (error) {
            reject(error);
          }
        }
      );
    });
  }

  confirmPayment(url: string): Promise<void> {
    return new Promise((resolve, reject) => {
      RNRYPay.confirmPayment(url, (result) => {
        if (result == "success") {
          resolve();
        } else {
          reject();
        }
      });
    });
  }

  cancel(): void {
    RNRYPay.cancel();
  }
}
