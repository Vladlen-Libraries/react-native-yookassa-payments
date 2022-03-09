import { NativeModules } from "react-native";

const RNRYPay = NativeModules.RNRYPaymentManager;

export function pay(info) {
  const paymentConfig = {
    api_key: info["api_key"],
    shop_name: info["shop_name"],
    shop_id: info["shop_id"],
    amount: info["amount"],
    purchase_description: info["purchase_description"],
    payment_types: info["payment_types"],
    test: info["test"],
    applePayMerchantIdentifier: info["applePayMerchantIdentifier"],
    returnUrl: info["returnUrl"],
    testMode: info["testMode"] ? info["testMode"] : 0,
  };
  return new Promise((resolve, reject) => {
    RNRYPay.pay(paymentConfig, (token, type, error) => {
      if (!!token && !!type) {
        resolve({
          token: token,
          type: type,
        });
      } else if (error) {
        reject(error);
      }
    });
  });
}

export function confirmPayment(url) {
  return new Promise((resolve, reject) => {
    RNRYPay.confirmPayment(url, (result) => {
      if (result === "success") {
        resolve();
      } else {
        reject();
      }
    });
  });
}

export function cancel() {
  RNRYPay.cancel();
}
