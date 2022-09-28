//
//  TapJoyAdapterConfiguration.swift
//  ChartboostHeliumAdapterTapJoy
//

import Tapjoy

/// A list of externally configurable properties pertaining to the partner SDK that can be retrieved and set by publishers.
public class TapJoyAdapterConfiguration {

    /// Flag that can optionally be set to enable the partner's test mode.
    /// Disabled by default.
    public static var testMode: Bool = false {
        didSet {
            Tapjoy.setDebugEnabled(testMode)
        }
    }

    /// Flag that can optionally be set to enable the partner's verbose logging.
    /// Disabled by default.
    public static var verboseLogging: Bool = false {
        didSet {
            Tapjoy.setDebugEnabled(verboseLogging)
        }
    }

    /// Append any other properties that publishers can configure.
}
