import { PaymentType } from "./PaymentType";

export interface PaymentConfig {
  shop_name: string;
  shop_id: number;
  amount: number;
  purchase_description: string;
  payment_types: PaymentType[];
  api_key: string;
  applePayMerchantIdentifier?: string;
  returnUrl?: string;
  testMode?: number;
}
