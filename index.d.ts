type PaymentType = "bank_card" | "apple_pay" | "google_pay";

export interface PaymentConfig {
  shop_name: string;
  shop_id: number;
  amount: number;
  purchase_description: string;
  payment_types: PaymentType;
  applePayMerchantIdentifier: string;
}

export interface PaymentInterface {
  apiKey: string | undefined;
  testMode: number;
  pay: (info: PaymentConfig) => Promise<PaymentResult>;
  confirmPayment: (url: string) => Promise<void>;
  cancel: () => void;
}

export interface PaymentResult {
  token: string;
  type: PaymentType;
}
