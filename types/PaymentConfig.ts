import { PaymentType } from "./PaymentType";

export interface PaymentConfig {
  shop_name: string;
  shop_id: number;
  amount: number;
  purchase_description: string;
  payment_types: PaymentType[];
  applePayMerchantIdentifier: string;
  api_key: string;
  test?: number;
}
