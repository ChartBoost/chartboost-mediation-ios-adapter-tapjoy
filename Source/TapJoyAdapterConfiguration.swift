//
//  TapJoyAdapterConfiguration.swift
//  ChartboostHeliumAdapterTapJoy
//

import Tapjoy

/// A list of externally configurable properties pertaining to the partner SDK that can be retrieved and set by publishers.
@objc public class TapJoyAdapterConfiguration: NSObject {
    
    /// Flag that can optionally be set to enable the partner's test mode.
    /// Disabled by default.
    @objc public static var testMode: Bool = false {
        didSet {
            Tapjoy.setDebugEnabled(testMode)
            print("TapJoy SDK test mode set to \(testMode)")
        }
    }
    
    /// Flag that can optionally be set to enable the partner's verbose logging.
    /// Disabled by default.
    @objc public static var verboseLogging: Bool = false {
        didSet {
            Tapjoy.setDebugEnabled(verboseLogging)
            print("TapJoy SDK verbose logging set to \(verboseLogging)")
        }
    }
}
