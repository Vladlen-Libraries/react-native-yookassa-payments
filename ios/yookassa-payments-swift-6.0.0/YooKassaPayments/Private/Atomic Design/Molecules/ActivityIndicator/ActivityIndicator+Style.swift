/* The MIT License
 *
 * Copyright © 2020 NBCO YooMoney LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit

// MARK: - Styles
extension ActivityIndicator {

    enum Styles {

        // MARK: - Complete appearance

        /// Default style
        ///
        /// Yellow color, large size, medium stroke
        static let `default` = Styles.primary + Styles.large + Styles.mediumStroke

        /// Secondary style
        ///
        /// Mustard color, extra extra large, large stroke
        static let secondary = Styles.primary + Styles.extraExtraLarge + Styles.largeStroke

        /// Primary style
        ///
        /// Spinner tint switch.
        static let primary =
                InternalStyle(name: "ActivityIndicator.primary") { (item: ActivityIndicator) in
                    item.spinnerColor = item.tintColor
                }

        // MARK: - Spinner size

        /// Small spinner style.
        ///
        /// 22pt size.
        static let small = InternalStyle(name: "small") { (activity: ActivityIndicator) in
            activity.spinnerSize = 22
        }

        /// Medium spinner style.
        ///
        /// 34pt size.
        static let medium = InternalStyle(name: "medium") { (activity: ActivityIndicator) in
            activity.spinnerSize = 34
        }

        /// Large spinner style.
        ///
        /// 52pt size.
        static let large = InternalStyle(name: "large") { (activity: ActivityIndicator) in
            activity.spinnerSize = 52
        }

        /// Extra large spinner style.
        ///
        /// 78pt size.
        static let extraLarge = InternalStyle(name: "extraLarge") { (activity: ActivityIndicator) in
            activity.spinnerSize = 78
        }

        /// Extra extra large spinner style.
        ///
        /// 80pt size.
        static let extraExtraLarge = InternalStyle(name: "extraExtraLarge") { (activity: ActivityIndicator) in
            activity.spinnerSize = 80
        }

        // MARK: - Stroke width

        /// Medium stroke spinner style.
        ///
        /// 2pt stroke with.
        static let mediumStroke = InternalStyle(name: "mediumStroke") { (activity: ActivityIndicator) in
            activity.strokeWidth = 2
        }

        /// Large stroke spinner style.
        ///
        /// 4pt stroke with.
        static let largeStroke = InternalStyle(name: "largeStroke") { (activity: ActivityIndicator) in
            activity.strokeWidth = 4
        }

        // MARK: - Spinner color

        /// Yellow spinner style.
        ///
        /// BrightSun color.
        private static let yellow = InternalStyle(name: "yellow") { (activity: ActivityIndicator) in
            activity.spinnerColor = .brightSun
        }

        /// Mustard spinner style.
        ///
        /// Mustard color.
        private static let mustard = InternalStyle(name: "mustard") { (activity: ActivityIndicator) in
            activity.spinnerColor = .mustard
        }

        /// Inverse spinner style.
        ///
        /// Inverse color.
        static let inverse = InternalStyle(name: "inverse") { (activity: ActivityIndicator) in
            activity.spinnerColor = .inverse

        }
    }
}
