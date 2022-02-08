enum PaymentServiceAssembly {
    static func makeService(
        tokenizationSettings: TokenizationSettings,
        testModeSettings: TestModeSettings?,
        isLoggingEnabled: Bool
    ) -> PaymentService {
        let service: PaymentService
        let paymentMethodHandlerService = PaymentMethodHandlerServiceAssembly
            .makeService(tokenizationSettings)

        switch testModeSettings {
        case let .some(testModeSettings):
            let keyValueStoring = KeyValueStoringAssembly.makeKeychainStorageMock(
                testModeSettings: testModeSettings
            )
            service = PaymentServiceMock(
                paymentMethodHandlerService: paymentMethodHandlerService,
                testModeSettings: testModeSettings,
                keyValueStoring: keyValueStoring
            )
        case .none:
            let session = ApiSessionAssembly
                .makeApiSession(isLoggingEnabled: isLoggingEnabled)
            service = PaymentServiceImpl(
                session: session,
                paymentMethodHandlerService: paymentMethodHandlerService
            )
        }
        return service
    }
}
