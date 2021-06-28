import PassKit
import MoneyAuth
import YooKassaPaymentsApi

final class PaymentMethodsPresenter: NSObject {

    private enum ApplePayState {
        case idle
        case success
        case cancel
    }

    private enum App2AppState {
        case idle
        case yoomoney
    }

    // MARK: - VIPER

    var interactor: PaymentMethodsInteractorInput!
    var router: PaymentMethodsRouterInput!
    weak var view: PaymentMethodsViewInput?
    weak var tokenizationModuleOutput: TokenizationModuleOutput?

    weak var bankCardModuleInput: BankCardModuleInput?
    weak var linkedCardModuleInput: LinkedCardModuleInput?

    // MARK: - Init data

    private let isLogoVisible: Bool
    private let paymentMethodViewModelFactory: PaymentMethodViewModelFactory
    private let priceViewModelFactory: PriceViewModelFactory

    private let applicationScheme: String?
    private let clientApplicationKey: String
    private let applePayMerchantIdentifier: String?
    private let testModeSettings: TestModeSettings?
    private let isLoggingEnabled: Bool
    private let moneyAuthClientId: String?
    private let tokenizationSettings: TokenizationSettings
    
    private let moneyAuthConfig: MoneyAuth.Config
    private let moneyAuthCustomization: MoneyAuth.Customization
    
    private let shopName: String
    private let purchaseDescription: String
    private let returnUrl: String
    private let savePaymentMethod: SavePaymentMethod
    private let userPhoneNumber: String?
    private let cardScanning: CardScanning?

    // MARK: - Init

    init(
        isLogoVisible: Bool,
        paymentMethodViewModelFactory: PaymentMethodViewModelFactory,
        applicationScheme: String?,
        priceViewModelFactory: PriceViewModelFactory,
        clientApplicationKey: String,
        applePayMerchantIdentifier: String?,
        testModeSettings: TestModeSettings?,
        isLoggingEnabled: Bool,
        moneyAuthClientId: String?,
        tokenizationSettings: TokenizationSettings,
        moneyAuthConfig: MoneyAuth.Config,
        moneyAuthCustomization: MoneyAuth.Customization,
        shopName: String,
        purchaseDescription: String,
        returnUrl: String?,
        savePaymentMethod: SavePaymentMethod,
        userPhoneNumber: String?,
        cardScanning: CardScanning?
    ) {
        self.isLogoVisible = isLogoVisible
        self.paymentMethodViewModelFactory = paymentMethodViewModelFactory
        self.priceViewModelFactory = priceViewModelFactory

        self.applicationScheme = applicationScheme
        self.clientApplicationKey = clientApplicationKey
        self.applePayMerchantIdentifier = applePayMerchantIdentifier
        self.testModeSettings = testModeSettings
        self.isLoggingEnabled = isLoggingEnabled
        self.moneyAuthClientId = moneyAuthClientId
        self.tokenizationSettings = tokenizationSettings
        
        self.moneyAuthConfig = moneyAuthConfig
        self.moneyAuthCustomization = moneyAuthCustomization
        
        self.shopName = shopName
        self.purchaseDescription = purchaseDescription
        self.returnUrl = returnUrl ?? GlobalConstants.returnUrl
        self.savePaymentMethod = savePaymentMethod
        self.userPhoneNumber = userPhoneNumber
        self.cardScanning = cardScanning
    }

    // MARK: - Stored properties

    private var moneyAuthCoordinator: MoneyAuth.AuthorizationCoordinator?
    private var yooMoneyTMXSessionId: String?

    private var paymentMethods: [PaymentOption]?
    private var viewModels: [PaymentMethodViewModel] = []
    
    private lazy var termsOfService: TermsOfService = {
        TermsOfServiceFactory.makeTermsOfService()
    }()

    private var shouldReloadOnViewDidAppear = false
    private var moneyCenterAuthToken: String?
    private var app2AppState: App2AppState = .idle

    // MARK: - Apple Pay properties

    private var applePayCompletion: ((PKPaymentAuthorizationStatus) -> Void)?
    private var applePayState: ApplePayState = .idle
    private var applePayPaymentOption: PaymentOption?
}

// MARK: - PaymentMethodsViewOutput

extension PaymentMethodsPresenter: PaymentMethodsViewOutput {
    func setupView() {
        guard let view = view else { return }
        view.showActivity()
        view.setLogoVisible(isLogoVisible)
        interactor.startAnalyticsService()

        DispatchQueue.global().async { [weak self] in
            self?.interactor.fetchPaymentMethods()
        }
    }

    func viewDidAppear() {
        guard shouldReloadOnViewDidAppear else { return }
        shouldReloadOnViewDidAppear = false
        DispatchQueue.global().async { [weak self] in
            guard let interactor = self?.interactor else { return }
            interactor.fetchPaymentMethods()
        }
    }
    
    func applicationDidBecomeActive() {
        if app2AppState == .idle,
           paymentMethods?.count == 1,
           paymentMethods?.first?.paymentMethodType == .yooMoney {
            didFinish(module: self, error: nil)
        }
    }

    func numberOfRows() -> Int {
        viewModels.count
    }
    
    func viewModelForRow(
        at indexPath: IndexPath
    ) -> PaymentMethodViewModel? {
        guard viewModels.indices.contains(indexPath.row) else {
            assertionFailure("ViewModel at index \(indexPath.row) should be")
            return nil
        }

        return viewModels[indexPath.row]
    }
    
    func didSelect(at indexPath: IndexPath) {
        guard let paymentMethods = paymentMethods,
              paymentMethods.indices.contains(indexPath.row) else {
            assertionFailure("ViewModel at index \(indexPath.row) should be")
            return
        }
        
        openPaymentMethod(
            paymentMethods[indexPath.row],
            needReplace: false
        )
    }
    
    private func openPaymentMethod(
        _ paymentOption: PaymentOption,
        needReplace: Bool
    ) {
        switch paymentOption {
        case let paymentOption as PaymentInstrumentYooMoneyLinkedBankCard:
            openLinkedCard(paymentOption: paymentOption, needReplace: needReplace)
            
        case let paymentOption as PaymentInstrumentYooMoneyWallet:
            openYooMoneyWallet(paymentOption: paymentOption, needReplace: needReplace)
            
        case let paymentOption where paymentOption.paymentMethodType == .yooMoney:
            openYooMoneyAuthorization()

        case let paymentOption where paymentOption.paymentMethodType == .sberbank:
            if shouldOpenSberpay(paymentOption),
               let returnUrl = makeSberpayReturnUrl() {
                openSberpayModule(paymentOption: paymentOption, needReplace: needReplace, returnUrl: returnUrl)
            } else {
                openSberbankModule(paymentOption: paymentOption, needReplace: needReplace)
            }

        case let paymentOption where paymentOption.paymentMethodType == .applePay:
            openApplePay(paymentOption: paymentOption, needReplace: needReplace)

        case let paymentOption where paymentOption.paymentMethodType == .bankCard:
            openBankCardModule(paymentOption: paymentOption, needReplace: needReplace)

        default:
            break
        }
    }
    
    private func openYooMoneyAuthorization() {
        if testModeSettings != nil {
            view?.showActivity()
            DispatchQueue.global().async {
                self.interactor.fetchYooMoneyPaymentMethods(
                    moneyCenterAuthToken: "MOCK_TOKEN"
                )
            }
        } else {
            if shouldOpenYooMoneyApp2App() {
                openYooMoneyApp2App()
            } else {
                openMoneyAuth()
            }
        }
    }

    private func openMoneyAuth() {
        do {
            moneyAuthCoordinator = try router.presentYooMoneyAuthorizationModule(
                config: moneyAuthConfig,
                customization: moneyAuthCustomization,
                output: self
            )
            let event = AnalyticsEvent.userStartAuthorization(
                sdkVersion: Bundle.frameworkVersion
            )
            interactor.trackEvent(event)
        } catch {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.view?.showActivity()
                DispatchQueue.global().async { [weak self] in
                    self?.interactor.fetchPaymentMethods()
                }
            }

            let event = AnalyticsEvent.userCancelAuthorization(
                sdkVersion: Bundle.frameworkVersion
            )
            interactor.trackEvent(event)
        }
    }
    
    private func openYooMoneyWallet(
        paymentOption: PaymentInstrumentYooMoneyWallet,
        needReplace: Bool
    ) {
        let walletDisplayName = interactor.getWalletDisplayName()
        let paymentMethod = paymentMethodViewModelFactory.makePaymentMethodViewModel(
            paymentOption: paymentOption,
            walletDisplayName: walletDisplayName
        )
        let initialSavePaymentMethod = makeInitialSavePaymentMethod(savePaymentMethod)
        let savePaymentMethodViewModel =  SavePaymentMethodViewModelFactory.makeSavePaymentMethodViewModel(
            paymentOption,
            savePaymentMethod,
            initialState: initialSavePaymentMethod
        )
        let priceViewModel = priceViewModelFactory.makeAmountPriceViewModel(paymentOption)
        let feeViewModel = priceViewModelFactory.makeFeePriceViewModel(paymentOption)
        let inputData = YooMoneyModuleInputData(
            clientApplicationKey: clientApplicationKey,
            testModeSettings: testModeSettings,
            isLoggingEnabled: isLoggingEnabled,
            moneyAuthClientId: moneyAuthClientId,
            tokenizationSettings: tokenizationSettings,
            shopName: shopName,
            purchaseDescription: purchaseDescription,
            price: priceViewModel,
            fee: feeViewModel,
            paymentMethod: paymentMethod,
            paymentOption: paymentOption,
            termsOfService: termsOfService,
            returnUrl: returnUrl,
            savePaymentMethodViewModel: savePaymentMethodViewModel,
            tmxSessionId: yooMoneyTMXSessionId,
            initialSavePaymentMethod: initialSavePaymentMethod,
            isBackBarButtonHidden: needReplace
        )
        router?.presentYooMoney(
            inputData: inputData,
            moduleOutput: self
        )
    }
    
    private func openLinkedCard(
        paymentOption: PaymentInstrumentYooMoneyLinkedBankCard,
        needReplace: Bool
    ) {
        let initialSavePaymentMethod = makeInitialSavePaymentMethod(savePaymentMethod)
        let priceViewModel = priceViewModelFactory.makeAmountPriceViewModel(paymentOption)
        let feeViewModel = priceViewModelFactory.makeFeePriceViewModel(paymentOption)
        let inputData = LinkedCardModuleInputData(
            clientApplicationKey: clientApplicationKey,
            testModeSettings: testModeSettings,
            isLoggingEnabled: isLoggingEnabled,
            moneyAuthClientId: moneyAuthClientId,
            tokenizationSettings: tokenizationSettings,
            shopName: shopName,
            purchaseDescription: purchaseDescription,
            price: priceViewModel,
            fee: feeViewModel,
            paymentOption: paymentOption,
            termsOfService: termsOfService,
            returnUrl: returnUrl,
            tmxSessionId: yooMoneyTMXSessionId,
            initialSavePaymentMethod: initialSavePaymentMethod,
            isBackBarButtonHidden: needReplace
        )
        router?.presentLinkedCard(
            inputData: inputData,
            moduleOutput: self
        )
    }

    private func openApplePay(
        paymentOption: PaymentOption,
        needReplace: Bool
    ) {
        let feeCondition = paymentOption.fee != nil
        let inputSavePaymentMethodCondition = savePaymentMethod == .userSelects
            || savePaymentMethod == .on
        let savePaymentMethodCondition = paymentOption.savePaymentMethod == .allowed
            && inputSavePaymentMethodCondition

        if feeCondition || savePaymentMethodCondition {
            let initialSavePaymentMethod = makeInitialSavePaymentMethod(savePaymentMethod)
            let savePaymentMethodViewModel =  SavePaymentMethodViewModelFactory.makeSavePaymentMethodViewModel(
                paymentOption,
                savePaymentMethod,
                initialState: initialSavePaymentMethod
            )
            let priceViewModel = priceViewModelFactory.makeAmountPriceViewModel(paymentOption)
            let feeViewModel = priceViewModelFactory.makeFeePriceViewModel(paymentOption)
            let inputData = ApplePayContractModuleInputData(
                clientApplicationKey: clientApplicationKey,
                testModeSettings: testModeSettings,
                isLoggingEnabled: isLoggingEnabled,
                tokenizationSettings: tokenizationSettings,
                shopName: shopName,
                purchaseDescription: purchaseDescription,
                price: priceViewModel,
                fee: feeViewModel,
                paymentOption: paymentOption,
                termsOfService: termsOfService,
                merchantIdentifier: applePayMerchantIdentifier,
                savePaymentMethodViewModel: savePaymentMethodViewModel,
                initialSavePaymentMethod: initialSavePaymentMethod,
                isBackBarButtonHidden: needReplace
            )
            router.presentApplePayContractModule(
                inputData: inputData,
                moduleOutput: self
            )
        } else {
            applePayPaymentOption = paymentOption

            let moduleInputData = ApplePayModuleInputData(
                merchantIdentifier: applePayMerchantIdentifier,
                amount: MonetaryAmountFactory.makeAmount(paymentOption.charge),
                shopName: shopName,
                purchaseDescription: purchaseDescription,
                supportedNetworks: ApplePayConstants.paymentNetworks,
                fee: paymentOption.fee?.plain
            )
            router.presentApplePay(
                inputData: moduleInputData,
                moduleOutput: self
            )
        }
    }

    private func openSberbankModule(
        paymentOption: PaymentOption,
        needReplace: Bool
    ) {
        let priceViewModel = priceViewModelFactory.makeAmountPriceViewModel(paymentOption)
        let feeViewModel = priceViewModelFactory.makeFeePriceViewModel(paymentOption)
        let inputData = SberbankModuleInputData(
            paymentOption: paymentOption,
            clientApplicationKey: clientApplicationKey,
            tokenizationSettings: tokenizationSettings,
            testModeSettings: testModeSettings,
            isLoggingEnabled: isLoggingEnabled,
            shopName: shopName,
            purchaseDescription: purchaseDescription,
            priceViewModel: priceViewModel,
            feeViewModel: feeViewModel,
            termsOfService: termsOfService,
            userPhoneNumber: userPhoneNumber,
            isBackBarButtonHidden: needReplace
        )
        router.openSberbankModule(
            inputData: inputData,
            moduleOutput: self
        )
    }

    private func openSberpayModule(
        paymentOption: PaymentOption,
        needReplace: Bool,
        returnUrl: String
    ) {
        let priceViewModel = priceViewModelFactory.makeAmountPriceViewModel(paymentOption)
        let feeViewModel = priceViewModelFactory.makeFeePriceViewModel(paymentOption)
        let inputData = SberpayModuleInputData(
            paymentOption: paymentOption,
            clientApplicationKey: clientApplicationKey,
            tokenizationSettings: tokenizationSettings,
            testModeSettings: testModeSettings,
            isLoggingEnabled: isLoggingEnabled,
            shopName: shopName,
            purchaseDescription: purchaseDescription,
            priceViewModel: priceViewModel,
            feeViewModel: feeViewModel,
            termsOfService: termsOfService,
            returnUrl: returnUrl,
            isBackBarButtonHidden: needReplace
        )
        router.openSberpayModule(
            inputData: inputData,
            moduleOutput: self
        )
    }

    private func openBankCardModule(
        paymentOption: PaymentOption,
        needReplace: Bool
    ) {
        let priceViewModel = priceViewModelFactory.makeAmountPriceViewModel(paymentOption)
        let feeViewModel = priceViewModelFactory.makeFeePriceViewModel(paymentOption)
        let initialSavePaymentMethod = makeInitialSavePaymentMethod(savePaymentMethod)
        let savePaymentMethodViewModel =  SavePaymentMethodViewModelFactory.makeSavePaymentMethodViewModel(
            paymentOption,
            savePaymentMethod,
            initialState: initialSavePaymentMethod
        )
        let inputData = BankCardModuleInputData(
            clientApplicationKey: clientApplicationKey,
            testModeSettings: testModeSettings,
            isLoggingEnabled: isLoggingEnabled,
            tokenizationSettings: tokenizationSettings,
            shopName: shopName,
            purchaseDescription: purchaseDescription,
            priceViewModel: priceViewModel,
            feeViewModel: feeViewModel,
            paymentOption: paymentOption,
            termsOfService: termsOfService,
            cardScanning: cardScanning,
            returnUrl: returnUrl,
            savePaymentMethodViewModel: savePaymentMethodViewModel,
            initialSavePaymentMethod: initialSavePaymentMethod,
            isBackBarButtonHidden: needReplace
        )
        router.openBankCardModule(
            inputData: inputData,
            moduleOutput: self
        )
    }

    private func shouldOpenSberpay(
        _ paymentOption: PaymentOption
    ) -> Bool {
        guard let confirmationTypes = paymentOption.confirmationTypes,
              confirmationTypes.contains(.mobileApplication) else {
            return false
        }

        return UIApplication.shared.canOpenURL(Constants.sberpayUrlScheme)
    }

    private func shouldOpenYooMoneyApp2App() -> Bool {
        guard let url = URL(string: Constants.YooMoneyApp2App.scheme) else {
            return false
        }

        return UIApplication.shared.canOpenURL(url)
    }

    private func openYooMoneyApp2App() {
        guard let clientId = moneyAuthClientId,
              let redirectUri = makeYooMoneyExchangeRedirectUri() else {
            return
        }

        let scope = makeYooMoneyApp2AppScope()
        let fullPathUrl = Constants.YooMoneyApp2App.scheme
            + "\(Constants.YooMoneyApp2App.host)/"
            + "\(Constants.YooMoneyApp2App.firstPath)?"
            + "\(Constants.YooMoneyApp2App.clientId)=\(clientId)&"
            + "\(Constants.YooMoneyApp2App.scope)=\(scope)&"
            + "\(Constants.YooMoneyApp2App.redirectUri)=\(redirectUri)"

        guard let url = URL(string: fullPathUrl) else {
            return
        }

        DispatchQueue.main.async {
            UIApplication.shared.open(
                url,
                options: [:],
                completionHandler: nil
            )
        }
    }

    private func makeYooMoneyExchangeRedirectUri() -> String? {
        guard let applicationScheme = applicationScheme else {
            assertionFailure("Application scheme should be")
            return nil
        }

        return applicationScheme
            + DeepLinkFactory.YooMoney.host
            + "/"
            + DeepLinkFactory.YooMoney.exchange.firstPath
            + "?"
            + DeepLinkFactory.YooMoney.exchange.cryptogram
            + "="
    }

    private func makeYooMoneyApp2AppScope() -> String {
        return [
            Constants.YooMoneyApp2App.Scope.accountInfo,
            Constants.YooMoneyApp2App.Scope.balance,
        ].joined(separator: ",")
    }
    
    private func makeSberpayReturnUrl() -> String? {
        guard let applicationScheme = applicationScheme else {
            assertionFailure("Application scheme should be")
            return nil
        }

        return applicationScheme
            + DeepLinkFactory.invoicingHost
            + "/"
            + DeepLinkFactory.sberpayPath
    }
}

// MARK: - ActionTitleTextDialogDelegate

extension PaymentMethodsPresenter: ActionTitleTextDialogDelegate {
    func didPressButton(
        in actionTitleTextDialog: ActionTitleTextDialog
    ) {
        guard let view = view else { return }
        view.hidePlaceholder()
        view.showActivity()
        
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            self.interactor.fetchPaymentMethods()
        }
    }
}

// MARK: - PaymentMethodsModuleInput

extension PaymentMethodsPresenter: PaymentMethodsModuleInput {
    func authorizeInYooMoney(
        with cryptogram: String
    ) {
        guard !cryptogram.isEmpty else {
            return
        }
        app2AppState = .yoomoney

        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let view = self.view else { return }
            view.showActivity()

            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                self.interactor.decryptCryptogram(cryptogram)
            }
        }
    }

    func didFinish(
        on module: TokenizationModuleInput,
        with error: YooKassaPaymentsError?
    ) {
        didFinish(module: module, error: error)
    }
}

// MARK: - PaymentMethodsInteractorOutput

extension PaymentMethodsPresenter: PaymentMethodsInteractorOutput {
    func didFetchPaymentMethods(_ paymentMethods: [PaymentOption]) {
        let (authType, _) = interactor.makeTypeAnalyticsParameters()
        let event: AnalyticsEvent = .screenPaymentOptions(
            authType: authType,
            sdkVersion: Bundle.frameworkVersion
        )
        interactor.trackEvent(event)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let view = self.view else { return }
            
            self.paymentMethods = paymentMethods

            if paymentMethods.count == 1, let paymentMethod = paymentMethods.first {
                self.openPaymentMethod(paymentMethod, needReplace: true)
            } else {
                let walletDisplayName = self.interactor.getWalletDisplayName()
                self.viewModels = paymentMethods.map {
                    self.paymentMethodViewModelFactory.makePaymentMethodViewModel(
                        paymentOption: $0,
                        walletDisplayName: walletDisplayName
                    )
                }
                view.hideActivity()
                view.reloadData()
            }
        }
    }

    func didFetchPaymentMethods(_ error: Error) {
        presentError(error)
    }
    
    func didFetchYooMoneyPaymentMethods(
        _ paymentMethods: [PaymentOption]
    ) {
        let condition: (PaymentOption) -> Bool = { $0 is PaymentInstrumentYooMoneyWallet }

        if let paymentOption = paymentMethods.first as? PaymentInstrumentYooMoneyWallet,
           paymentMethods.count == 1 {
            let needReplace = self.paymentMethods?.count == 1
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.openYooMoneyWallet(
                    paymentOption: paymentOption,
                    needReplace: needReplace
                )
                self.shouldReloadOnViewDidAppear = true
            }
        } else if paymentMethods.contains(where: condition) == false {
            let event: AnalyticsEvent = .actionAuthWithoutWallet(
                sdkVersion: Bundle.frameworkVersion
            )
            interactor.trackEvent(event)
            interactor.fetchPaymentMethods()
            DispatchQueue.main.async { [weak self] in
                guard let view = self?.view else { return }
                view.presentError(with: §Localized.Error.noWalletTitle)
            }
        } else {
            interactor.fetchPaymentMethods()
        }
    }

    func didFetchYooMoneyPaymentMethods(_ error: Error) {
        presentError(error)
    }
    
    func didFetchAccount(
        _ account: UserAccount
    ) {
        guard let moneyCenterAuthToken = moneyCenterAuthToken else {
            return
        }
        interactor.setAccount(account)
        interactor.fetchYooMoneyPaymentMethods(
            moneyCenterAuthToken: moneyCenterAuthToken
        )
    }

    func didFailFetchAccount(
        _ error: Error
    ) {
        guard let moneyCenterAuthToken = moneyCenterAuthToken else {
            return
        }
        interactor.fetchYooMoneyPaymentMethods(
            moneyCenterAuthToken: moneyCenterAuthToken
        )
    }

    func didDecryptCryptogram(
        _ token: String
    ) {
        moneyCenterAuthToken = token
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            let event: AnalyticsEvent = .actionMoneyAuthLogin(
                scheme: .yoomoneyApp,
                status: .success,
                sdkVersion: Bundle.frameworkVersion
            )
            self.interactor.trackEvent(event)
            self.interactor.fetchAccount(oauthToken: token)
        }
    }

    func didFailDecryptCryptogram(
        _ error: Error
    ) {
        let event: AnalyticsEvent = .actionMoneyAuthLogin(
            scheme: .yoomoneyApp,
            status: .fail(error.localizedDescription),
            sdkVersion: Bundle.frameworkVersion
        )
        interactor.trackEvent(event)
        DispatchQueue.main.async { [weak self] in
            guard let view = self?.view else { return }
            view.hideActivity()
            view.presentError(with: §CommonLocalized.Error.unknown)
        }
    }

    func didTokenizeApplePay(
        _ token: Tokens
    ) {
        guard applePayState == .success else {
            return
        }

        applePayCompletion?(.success)

        let parameters = interactor.makeTypeAnalyticsParameters()
        let event: AnalyticsEvent = .actionTokenize(
            scheme: .applePay,
            authType: parameters.authType,
            tokenType: parameters.tokenType,
            sdkVersion: Bundle.frameworkVersion
        )
        interactor.trackEvent(event)

        DispatchQueue.main.asyncAfter(
            deadline: .now() + Constants.dismissApplePayTimeout
        ) { [weak self] in
            guard let self = self else { return }
            self.router.closeApplePay {
                self.didTokenize(
                    tokens: token,
                    paymentMethodType: .applePay,
                    scheme: .applePay
                )
            }
        }
    }

    func failTokenizeApplePay(
        _ error: Error
    ) {
        guard applePayState == .success else {
            return
        }

        trackScreenErrorAnalytics(scheme: .applePay)
        applePayCompletion?(.failure)

        DispatchQueue.main.asyncAfter(
            deadline: .now() + Constants.dismissApplePayTimeout
        ) { [weak self] in
            guard let self = self else { return }
            self.router.closeApplePay() { [weak self] in
                guard let self = self else { return }
                
                let message = §Localized.Error.failTokenizeData
                if self.paymentMethods?.count == 1 {
                    self.view?.hideActivity()
                    self.view?.showPlaceholder(message: message)
                } else {
                    self.view?.presentError(with: message)
                }
            }
        }
    }

    private func presentError(_ error: Error) {
        let message: String

        switch error {
        case let error as PresentableError:
            message = error.message
        default:
            message = §CommonLocalized.Error.unknown
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self, let view = self.view else { return }
            view.hideActivity()
            view.showPlaceholder(message: message)

            self.trackScreenErrorAnalytics(scheme: nil)
        }
    }

    private func trackScreenErrorAnalytics(
        scheme: AnalyticsEvent.TokenizeScheme?
    ) {
        DispatchQueue.global().async { [weak self] in
            guard let interactor = self?.interactor else { return }
            let (authType, _) = interactor.makeTypeAnalyticsParameters()
            let event: AnalyticsEvent = .screenError(
                authType: authType,
                scheme: scheme,
                sdkVersion: Bundle.frameworkVersion
            )
            interactor.trackEvent(event)
        }
    }

    private func trackScreenPaymentAnalytics(
        scheme: AnalyticsEvent.TokenizeScheme
    ) {
        DispatchQueue.global().async { [weak self] in
            guard let interactor = self?.interactor else { return }
            let (authType, _) = interactor.makeTypeAnalyticsParameters()
            let event: AnalyticsEvent = .screenPaymentContract(
                authType: authType,
                scheme: scheme,
                sdkVersion: Bundle.frameworkVersion
            )
            interactor.trackEvent(event)
        }
    }
}

// MARK: - ProcessCoordinatorDelegate

extension PaymentMethodsPresenter: AuthorizationCoordinatorDelegate {
    func authorizationCoordinator(
        _ coordinator: AuthorizationCoordinator,
        didAcquireAuthorizationToken token: String,
        account: UserAccount,
        authorizationProcess: AuthorizationProcess?,
        tmxSessionId: String?,
        phoneOffersAccepted: Bool,
        emailOffersAccepted: Bool,
        userAgreementAccepted: Bool,
        bindSocialAccountResult: BindSocialAccountResult?
    ) {
        self.moneyAuthCoordinator = nil
        self.yooMoneyTMXSessionId = tmxSessionId

        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let view = self.view else { return }
            self.router.closeAuthorizationModule()
            view.showActivity()

            DispatchQueue.global().async { [weak self] in
                guard let self = self else { return }
                self.interactor.setAccount(account)
                self.interactor.fetchYooMoneyPaymentMethods(
                    moneyCenterAuthToken: token
                )

                let event: AnalyticsEvent = .actionMoneyAuthLogin(
                    scheme: .moneyAuthSdk,
                    status: .success,
                    sdkVersion: Bundle.frameworkVersion
                )
                self.interactor.trackEvent(event)
            }
        }
    }

    func authorizationCoordinatorDidCancel(
        _ coordinator: AuthorizationCoordinator
    ) {
        self.moneyAuthCoordinator = nil

        let event = AnalyticsEvent.userCancelAuthorization(
            sdkVersion: Bundle.frameworkVersion
        )
        interactor.trackEvent(event)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.router.shouldDismissAuthorizationModule() {
                self.router.closeAuthorizationModule()
            }
            if self.paymentMethods?.count == 1 {
                self.didFinish(module: self, error: nil)
            }
        }
    }

    func authorizationCoordinator(
        _ coordinator: AuthorizationCoordinator,
        didFailureWith error: Error
    ) {
        self.moneyAuthCoordinator = nil

        let event: AnalyticsEvent = .actionMoneyAuthLogin(
            scheme: .moneyAuthSdk,
            status: .fail(error.localizedDescription),
            sdkVersion: Bundle.frameworkVersion
        )
        interactor.trackEvent(event)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.router.closeAuthorizationModule()
            self.view?.showActivity()
            DispatchQueue.global().async { [weak self] in
                self?.interactor.fetchPaymentMethods()
            }
        }
    }

    func authorizationCoordinatorDidPrepareProcess(
        _ coordinator: AuthorizationCoordinator
    ) {}

    func authorizationCoordinator(
        _ coordinator: AuthorizationCoordinator,
        didFailPrepareProcessWithError error: Error
    ) {}

    func authorizationCoordinatorDidRecoverPassword(
        _ coordinator: AuthorizationCoordinator
    ) {}
}

// MARK: - YooMoneyModuleOutput

extension PaymentMethodsPresenter: YooMoneyModuleOutput {
    func didLogout(
        _ module: YooMoneyModuleInput
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.moneyCenterAuthToken = nil
            self.app2AppState = .idle
            let condition: (PaymentOption) -> Bool = {
                $0 is PaymentInstrumentYooMoneyLinkedBankCard
                || $0 is PaymentInstrumentYooMoneyWallet
                || $0.paymentMethodType == .yooMoney
            }
            if let paymentMethods = self.paymentMethods,
               paymentMethods.allSatisfy(condition) {
                self.didFinish(module: self, error: nil)
            } else {
                self.shouldReloadOnViewDidAppear = false
                self.router.closeYooMoneyModule()
                self.view?.showActivity()
                DispatchQueue.global().async { [weak self] in
                    self?.interactor.fetchPaymentMethods()
                }
            }
        }
    }
    
    func tokenizationModule(
        _ module: YooMoneyModuleInput,
        didTokenize token: Tokens,
        paymentMethodType: PaymentMethodType
    ) {
        didTokenize(
            tokens: token,
            paymentMethodType: paymentMethodType,
            scheme: .wallet
        )
    }
}

// MARK: - LinkedCardModuleOutput

extension PaymentMethodsPresenter: LinkedCardModuleOutput {
    func tokenizationModule(
        _ module: LinkedCardModuleInput,
        didTokenize token: Tokens,
        paymentMethodType: PaymentMethodType
    ) {
        linkedCardModuleInput = module
        didTokenize(
            tokens: token,
            paymentMethodType: paymentMethodType,
            scheme: .linkedCard
        )
    }
}

// MARK: - ApplePayModuleOutput

extension PaymentMethodsPresenter: ApplePayModuleOutput {
    func didPresentApplePayModule() {
        applePayState = .idle
        trackScreenPaymentAnalytics(scheme: .applePay)
    }

    func didFailPresentApplePayModule() {
        applePayState = .idle
        trackScreenErrorAnalytics(scheme: .applePay)

        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let view = self.view else { return }
            
            let message = §Localized.applePayUnavailableTitle
            if self.paymentMethods?.count == 1 {
                view.hideActivity()
                view.showPlaceholder(message: message)
            } else {
                view.presentError(with: message)
            }
        }
    }

    @available(iOS 11.0, *)
    func paymentAuthorizationViewController(
        _ controller: PKPaymentAuthorizationViewController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        paymentAuthorizationViewController(
            controller,
            didAuthorizePayment: payment
        ) { status in
            completion(PKPaymentAuthorizationResult(status: status, errors: nil))
        }
    }

    func paymentAuthorizationViewController(
        _ controller: PKPaymentAuthorizationViewController,
        didAuthorizePayment payment: PKPayment,
        completion: @escaping (PKPaymentAuthorizationStatus) -> Void
    ) {
        guard applePayState != .cancel,
              let paymentOption = applePayPaymentOption else { return }

        applePayState = .success
        applePayCompletion = completion

        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }

            let initialSavePaymentMethod = makeInitialSavePaymentMethod(self.savePaymentMethod)
            self.interactor.tokenizeApplePay(
                paymentData: payment.token.paymentData.base64EncodedString(),
                savePaymentMethod: initialSavePaymentMethod,
                amount: paymentOption.charge.plain
            )
        }
    }

    func paymentAuthorizationViewControllerDidFinish(
        _ controller: PKPaymentAuthorizationViewController
    ) {
        router.closeApplePay(completion: nil)
        applePayState = .cancel
        
        if paymentMethods?.count == 1 {
            didFinish(module: self, error: nil)
        }
    }
}

// MARK: - ApplePayContractModuleOutput

extension PaymentMethodsPresenter: ApplePayContractModuleOutput {
    func tokenizationModule(
        _ module: ApplePayContractModuleInput,
        didTokenize token: Tokens,
        paymentMethodType: PaymentMethodType
    ) {
        didTokenize(
            tokens: token,
            paymentMethodType: paymentMethodType,
            scheme: .applePay
        )
    }
}

// MARK: - SberbankModuleOutput

extension PaymentMethodsPresenter: SberbankModuleOutput {
    func sberbankModule(
        _ module: SberbankModuleInput,
        didTokenize token: Tokens,
        paymentMethodType: PaymentMethodType
    ) {
        didTokenize(
            tokens: token,
            paymentMethodType: paymentMethodType,
            scheme: .smsSbol
        )
    }
}

// MARK: - SberpayModuleOutput

extension PaymentMethodsPresenter: SberpayModuleOutput {
    func sberpayModule(
        _ module: SberpayModuleInput,
        didTokenize token: Tokens,
        paymentMethodType: PaymentMethodType
    ) {
        didTokenize(
            tokens: token,
            paymentMethodType: paymentMethodType,
            scheme: .sberpay
        )
    }
}

// MARK: - BankCardModuleOutput

extension PaymentMethodsPresenter: BankCardModuleOutput {
    func bankCardModule(
        _ module: BankCardModuleInput,
        didTokenize token: Tokens,
        paymentMethodType: PaymentMethodType
    ) {
        bankCardModuleInput = module
        didTokenize(
            tokens: token,
            paymentMethodType: paymentMethodType,
            scheme: .bankCard
        )
    }
}

// MARK: - TokenizationModuleInput

extension PaymentMethodsPresenter: TokenizationModuleInput {
    func start3dsProcess(
        requestUrl: String
    ) {
        let inputData = CardSecModuleInputData(
            requestUrl: requestUrl,
            redirectUrl: GlobalConstants.returnUrl,
            isLoggingEnabled: isLoggingEnabled,
            isConfirmation: false
        )
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.router.openCardSecModule(
                inputData: inputData,
                moduleOutput: self
            )
        }
    }

    func startConfirmationProcess(
        confirmationUrl: String,
        paymentMethodType: PaymentMethodType
    ) {
        switch paymentMethodType {
        case .sberbank:
            guard let url = URL(string: confirmationUrl) else {
                return
            }

            DispatchQueue.main.async {
                UIApplication.shared.open(
                    url,
                    options: [:],
                    completionHandler: nil
                )
            }

        default:
            let inputData = CardSecModuleInputData(
                requestUrl: confirmationUrl,
                redirectUrl: GlobalConstants.returnUrl,
                isLoggingEnabled: isLoggingEnabled,
                isConfirmation: true
            )
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.router.openCardSecModule(
                    inputData: inputData,
                    moduleOutput: self
                )
            }
        }
    }
}

// MARK: - CardSecModuleOutput

extension PaymentMethodsPresenter: CardSecModuleOutput {
    func didSuccessfullyPassedCardSec(
        on module: CardSecModuleInput,
        isConfirmation: Bool
    ) {
        interactor.stopAnalyticsService()
        if isConfirmation {
            tokenizationModuleOutput?.didSuccessfullyConfirmation(
                paymentMethodType: .bankCard
            )
        } else {
            tokenizationModuleOutput?.didSuccessfullyPassedCardSec(
                on: self
            )
        }
    }

    func didPressCloseButton(
        on module: CardSecModuleInput
    ) {
        router.closeCardSecModule()
        bankCardModuleInput?.hideActivity()
        linkedCardModuleInput?.hideActivity()
    }

    func viewWillDisappear() {
        bankCardModuleInput?.hideActivity()
        linkedCardModuleInput?.hideActivity()
    }
}

// MARK: - Private helpers

private extension PaymentMethodsPresenter {
    func didTokenize(
        tokens: Tokens,
        paymentMethodType: PaymentMethodType,
        scheme: AnalyticsEvent.TokenizeScheme
    ) {
        interactor.stopAnalyticsService()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.tokenizationModuleOutput?.tokenizationModule(
                self,
                didTokenize: tokens,
                paymentMethodType: paymentMethodType
            )
        }
    }

    func didFinish(
        module: TokenizationModuleInput,
        error: YooKassaPaymentsError?
    ) {
        interactor.stopAnalyticsService()
        tokenizationModuleOutput?.didFinish(
            on: module,
            with: error
        )
    }
}

// MARK: - Constants

private extension PaymentMethodsPresenter {
    enum Constants {
        static let dismissApplePayTimeout: TimeInterval = 0.5

        // swiftlint:disable:next force_unwrapping
        static let sberpayUrlScheme = URL(string: "sberpay://")!

        enum YooMoneyApp2App {
            // yoomoneyauth://app2app/exchange?clientId={clientId}&scope={scope}&redirect_uri={redirect_uri}
            // swiftlint:disable:next force_unwrapping
            static let scheme = "yoomoneyauth://"
            static let host = "app2app"
            static let firstPath = "exchange"
            static let clientId = "clientId"
            static let scope = "scope"
            static let redirectUri = "redirect_uri"

            enum Scope {
                static let accountInfo = "user_auth_center:account_info"
                static let balance = "wallet:balance"
            }

        }
    }
}

// MARK: - Localized

private extension PaymentMethodsPresenter {
    enum Localized: String {
        case applePayUnavailableTitle = "ApplePayUnavailable.title"

        enum Error: String {
            case failTokenizeData = "Error.ApplePayStrategy.failTokenizeData"
            case noWalletTitle = "Error.noWalletTitle"
        }
    }
}

// MARK: - Private global helpers

private func makeInitialSavePaymentMethod(
    _ savePaymentMethod: SavePaymentMethod
) -> Bool {
    let initialSavePaymentMethod: Bool
    switch savePaymentMethod {
    case .on:
        initialSavePaymentMethod = true
    case .off, .userSelects:
        initialSavePaymentMethod = false
    }
    return initialSavePaymentMethod
}
