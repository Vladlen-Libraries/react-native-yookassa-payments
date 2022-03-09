package com.paymentrn;

import android.app.Activity;
import android.content.Intent;
import androidx.annotation.NonNull;

import com.facebook.react.bridge.ActivityEventListener;
import com.facebook.react.bridge.Callback;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.BaseActivityEventListener;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.paymentrn.settings.Settings;

import java.math.BigDecimal;
import java.util.Currency;
import java.util.HashSet;
import java.util.Set;

import ru.yoomoney.sdk.kassa.payments.checkoutParameters.Amount;
import ru.yoomoney.sdk.kassa.payments.Checkout;
import ru.yoomoney.sdk.kassa.payments.checkoutParameters.PaymentParameters;
import ru.yoomoney.sdk.kassa.payments.TokenizationResult;
import ru.yoomoney.sdk.kassa.payments.checkoutParameters.PaymentMethodType;
import ru.yoomoney.sdk.kassa.payments.checkoutParameters.TestParameters;
import ru.yoomoney.sdk.kassa.payments.checkoutParameters.MockConfiguration;

public class YooKassaModule extends ReactContextBaseJavaModule {

    private final ReactApplicationContext reactContext;

    private static final int REQUEST_CODE_TOKENIZE = 33;
    private static final int REQUEST_CODE_3DSECURE = 35;
    private Callback paymentCallback;

    public YooKassaModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.reactContext = reactContext;
        reactContext.addActivityEventListener(mActivityEventListener);
    }

    @Override
    public String getName() {
        return "RNRYPaymentManager";
    }

    @ReactMethod
    public void pay(ReadableMap obj, Callback callback) {

        final Settings settings = new Settings(this.reactContext);
        this.paymentCallback = callback;

        String amount = String.valueOf(obj.getDouble("amount"));
        String title = obj.getString("shop_name");
        String subtitle = obj.getString("purchase_description");
        String clientApplicationKey = obj.getString("api_key");
        String shopId = String.valueOf(obj.getDouble("shop_id"));
        String customReturnUrl = obj.getString("returnUrl");
        String gatewayId = null;
        String testMode = obj.getDouble("testMode");
        ReadableArray paymentTypes = obj.getArray("payment_types");


        final Set<PaymentMethodType> paymentMethodTypes = getPaymentMethodTypes(paymentTypes);

        TestParameters testParameters = new TestParameters(true, true,
                    new MockConfiguration(false, true, 5, new Amount(BigDecimal.TEN, Currency.getInstance("RUB"))));

        PaymentParameters paymentParameters = new PaymentParameters(
                new Amount(new BigDecimal(amount), Currency.getInstance("RUB")),
                title,
                subtitle,
                clientApplicationKey,
                shopId,
                settings.getSavePaymentMethod(),
                paymentMethodTypes,
                gatewayId,
                customReturnUrl
        );

        if (testMode > 0) {
            Intent intent = Checkout.createTokenizeIntent(this.reactContext, paymentParameters, testParameters);
            getCurrentActivity().startActivityForResult(intent, REQUEST_CODE_TOKENIZE);
        } else {
            Intent intent = Checkout.createTokenizeIntent(this.reactContext, paymentParameters);
            getCurrentActivity().startActivityForResult(intent, REQUEST_CODE_TOKENIZE);
        }
    }

    @ReactMethod
    public void confirmPayment(String url, Callback callback) {
        this.paymentCallback = callback;
        Intent intent = Checkout.create3dsIntent(this.reactContext, url);
        // Intent intent = Checkout.createConfirmationIntent(this.reactContext, url);
        Activity activity = getCurrentActivity();

        if (activity == null) {
            paymentCallback.invoke(null,null,"error");
            return;
        }

        activity.startActivityForResult(intent, REQUEST_CODE_3DSECURE);
    }

    @NonNull
    private static Set<PaymentMethodType> getPaymentMethodTypes(ReadableArray paymentTypes) {
        final Set<PaymentMethodType> paymentMethodTypes = new HashSet<>();

        for (int i = 0; i < paymentTypes.size(); i++) {
            String upperType = paymentTypes.getString(i).toUpperCase();
            switch (upperType) {
                case "BANK_CARD":
                    paymentMethodTypes.add(PaymentMethodType.BANK_CARD);
                    break;
                case "SBERBANK":
                    paymentMethodTypes.add(PaymentMethodType.SBERBANK);
                    break;
                case "GOOGLE_PAY":
                    paymentMethodTypes.add(PaymentMethodType.GOOGLE_PAY);
                    break;
                case "YOO_MONEY":
                    paymentMethodTypes.add(PaymentMethodType.YOO_MONEY);
                    break;
            }
        }

        return paymentMethodTypes;
    }

    private final ActivityEventListener mActivityEventListener = new BaseActivityEventListener() {

        @Override
        public void onActivityResult(Activity activity, int requestCode, int resultCode, Intent data) {

            if (requestCode == REQUEST_CODE_TOKENIZE) {

                switch (resultCode) {
                    case Activity.RESULT_OK:
                        final TokenizationResult result = Checkout.createTokenizationResult(data);
                        String token = result.getPaymentToken();
                        String type = result.getPaymentMethodType().name().toLowerCase();
                        paymentCallback.invoke(token, type);
                        break;

                    case Activity.RESULT_CANCELED:
                        paymentCallback.invoke(null,null,"Payment cancelled");
                        break;
                }
            }

            if (requestCode == REQUEST_CODE_3DSECURE) {
                switch (resultCode) {
                    case Activity.RESULT_OK:
                        paymentCallback.invoke("success");
                        break;

                    case Activity.RESULT_CANCELED:
                    case Checkout.RESULT_ERROR:
                        paymentCallback.invoke(null,null,"Payment cancelled");
                        break;
                }
            }

        }
    };
}
