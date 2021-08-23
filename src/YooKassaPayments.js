import React from 'react';
import {NativeModules} from 'react-native';
const RNRYPay = NativeModules.RNRYPaymentManager;

export default class RNRYPayment {
    async pay(info) {
        return new Promise(async (resolve, reject) => {
            RNRYPay.pay({
                "api_key": this.apiKey,
                "shop_name": info["shop_name"],
                "shop_id": info["shop_id"],
                "amount": info["amount"],
                "purchase_description": info["purchase_description"],
                "payment_types": info["payment_types"],
                "test": this.testMode,
                "applePayMerchantIdentifier": info["applePayMerchantIdentifier"],
            }, (token: string, type: string, error: any) => {
                console.log(token,type,error)
                if (!!token && !!type) {
                    resolve({
                        token: token,
                        type: type,
                    });
                } else if (error) {
                    reject(error)
                }
            });
        });
    }

    confirmPayment = async (url) => {
        return new Promise(async (resolve, reject) => {
            RNRYPay.confirmPayment(url, (result) => {
                if (result == "success") {
                    resolve({"result": "success"})
                } else {
                    reject({"result": "error"})
                }
            });
        });
    }

    cancel() {
        RNRYPay.cancel();
    }
}
