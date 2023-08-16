// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import Tapjoy
import os.log

/// A list of externally configurable properties pertaining to the partner SDK that can be retrieved and set by publishers.
@objc public class TapjoyAdapterConfiguration: NSObject {
    
    private static let log = OSLog(subsystem: "com.chartboost.mediation.adapter.tapjoy", category: "Configuration")

    /// Flag that can optionally be set to enable the partner's test mode.
    /// Disabled by default.
    @objc public static var testMode: Bool = false {
        didSet {
            Tapjoy.setDebugEnabled(testMode)
            if #available(iOS 12.0, *) {
                os_log(.debug, log: log, "Tapjoy SDK test mode set to %{public}s", "\(testMode)")
            }
        }
    }
    
    /// Flag that can optionally be set to enable the partner's verbose logging.
    /// Disabled by default.
    @objc public static var verboseLogging: Bool = false {
        didSet {
            Tapjoy.setDebugEnabled(verboseLogging)
            if #available(iOS 12.0, *) {
                os_log(.debug, log: log, "Tapjoy SDK verbose logging set to %{public}s", "\(verboseLogging)")
            }
        }
    }
}
