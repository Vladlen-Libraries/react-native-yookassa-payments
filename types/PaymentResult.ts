import { PaymentType } from "./PaymentType";

export interface PaymentResult {
  token: string;
  type: PaymentType;
}
