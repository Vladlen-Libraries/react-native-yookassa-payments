/// Type of the source of funds for the payment.
public struct PaymentMethodTypes: OptionSet {

    public private(set) var rawValue: Set<PaymentMethodType>

    /// Any Bank card.
    public static let bankCard = PaymentMethodTypes(rawValue: [.bankCard])

    /// YooMoney Wallet.
    public static let yooMoney = PaymentMethodTypes(rawValue: [.yooMoney])

    /// Sberbank Online
    public static let sberbank = PaymentMethodTypes(rawValue: [.sberbank])

    /// Apple Pay
    public static let applePay = PaymentMethodTypes(rawValue: [.applePay])

    /// All the available methods.
    public static let all: PaymentMethodTypes = [
        .bankCard, .yooMoney, .applePay, .sberbank,
    ]

    // MARK: - SetAlgebra

    /// Creates instance of `PaymentMethodTypes`.
    ///
    /// - Returns: Instance of `PaymentMethodTypes`.
    public init() {
        self.init(rawValue: [])
    }

    public init(rawValue: Set<PaymentMethodType>) {
        self.rawValue = rawValue
    }

    public mutating func formUnion(_ other: PaymentMethodTypes) {
        rawValue = rawValue.union(other.rawValue)
    }

    public mutating func formIntersection(_ other: PaymentMethodTypes) {
        rawValue = rawValue.intersection(other.rawValue)
    }

    public mutating func formSymmetricDifference(_ other: PaymentMethodTypes) {
        rawValue = rawValue.symmetricDifference(other.rawValue)
    }

    // MARK: - Equatable

    public static func == (lhs: PaymentMethodTypes, rhs: PaymentMethodTypes) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
}
