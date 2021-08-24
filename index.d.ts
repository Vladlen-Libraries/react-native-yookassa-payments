import { PaymentConfig } from "./types/PaymentConfig";
import { PaymentResult } from "./types/PaymentResult";

export function pay(info: PaymentConfig): Promise<PaymentResult>;

export function confirmPayment(url: string): Promise<void>;

export function cancel(): void;
