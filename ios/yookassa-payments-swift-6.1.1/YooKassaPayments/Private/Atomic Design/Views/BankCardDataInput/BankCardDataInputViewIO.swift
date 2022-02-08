import UIKit

enum BankCardDataInputViewErrorState {
    case noError
    case panError
    case expiryDateError
    case invalidCvc
}

protocol BankCardDataInputViewInput: AnyObject {
    var focus: BankCardDataInputView.BankCardFocus? { get set }

    func setViewModel(
        _ viewModel: BankCardDataInputViewModel
    )
    func setBankLogoImage(
        _ image: UIImage?
    )
    func setCardViewMode(
        _ mode: InputPanCardView.RightButtonMode
    )
    func setPanValue(
        _ value: String
    )
    func setExpiryDateValue(
        _ value: String
    )
    func setInputState(
        _ state: BankCardDataInputView.InputState
    )
    func setErrorState(
        _ state: BankCardDataInputViewErrorState
    )
}

protocol BankCardDataInputViewOutput: AnyObject {
    func setupView()

    func didPressScan()
    func panDidBeginEditing()
    func expiryDateDidBeginEditing()
    func expiryDateDidEndEditing()
    func cvcDidEndEditing()
    func nextDidPress()
    func clearDidPress()

    func didChangePan(
        _ value: String
    )
    func didChangeExpiryDate(
        _ value: String
    )
    func didChangeCvc(
        _ value: String
    )
}
