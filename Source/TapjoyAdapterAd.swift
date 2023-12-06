// Copyright 2022-2023 Chartboost, Inc.
//
// Use of this source code is governed by an MIT-style
// license that can be found in the LICENSE file.

import ChartboostMediationSDK
import Foundation
import Tapjoy
import UIKit

/// The Chartboost Mediation Tapjoy adapter ad.
final class TapjoyAdapterAd: NSObject, PartnerAd {
    
    /// The partner adapter that created this ad.
    let adapter: PartnerAdapter
    
    /// The ad load request associated to the ad.
    /// It should be the one provided on `PartnerAdapter.makeAd(request:delegate:)`.
    let request: PartnerAdLoadRequest
        
    /// The partner ad delegate to send ad life-cycle events to.
    /// It should be the one provided on `PartnerAdapter.makeAd(request:delegate:)`.
    weak var delegate: PartnerAdDelegate?
    
    /// The partner ad view to display inline. E.g. a banner view.
    /// Should be nil for full-screen ads.
    var inlineView: UIView? { nil }
    
    /// The completion handler to notify Chartboost Mediation of ad load completion result.
    var loadCompletion: ((Result<PartnerEventDetails, Error>) -> Void)?
    
    /// The completion handler to notify Chartboost Mediation of ad load completion result.
    var showCompletion: ((Result<PartnerEventDetails, Error>) -> Void)?
    
    /// The Tapjoy SDK placement to load and show ads.
    private let placement: TJPlacement
    
    init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws {
        self.adapter = adapter
        self.request = request
        self.delegate = delegate
        if let placement = TJPlacement(name: request.partnerPlacement, delegate: nil) {
            self.placement = placement
        } else {
            throw adapter.error(.loadFailureAborted, description: "Failed to create TJPlacement")
        }
    }
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        
        loadCompletion = completion
        
        // Configure the placement
        placement.placementName = request.partnerPlacement
        placement.delegate = self

        // Load ad
        placement.requestContent()
    }
    
    /// Shows a loaded ad.
    /// It will never get called for banner ads. You may leave the implementation blank for that ad format.
    /// - parameter viewController: The view controller on which the ad will be presented on.
    /// - parameter completion: Closure to be performed once the ad has been shown.
    func show(with viewController: UIViewController, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.showStarted)
        
        // Fail early if ad is not ready
        guard placement.isContentReady && placement.isContentAvailable else {
            let error = error(.showFailureAdNotReady)
            log(.showFailed(error))
            completion(.failure(error))
            return
        }
        
        // Show ad
        showCompletion = completion
        placement.showContent(with: viewController)
    }
}

extension TapjoyAdapterAd: TJPlacementDelegate {
    
    func requestDidSucceed(_ placement: TJPlacement) {
        if !placement.isContentAvailable {
            let error = error(.loadFailureUnknown, description: "No content available")
            log(.loadFailed(error))
            loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
            loadCompletion = nil
        } else {
            // Do nothing, we complete on contentIsReady()
            log(.delegateCallIgnored)
        }
    }
    
    func requestDidFail(_ placement: TJPlacement, error partnerError: Error?) {
        let error = partnerError ?? error(.loadFailureUnknown)
        log(.loadFailed(error))
        loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
    
    func contentIsReady(_ placement: TJPlacement) {
        log(.loadSucceeded)
        loadCompletion?(.success([:])) ?? log(.loadResultIgnored)
        loadCompletion = nil
    }
    
    func contentDidAppear(_ placement: TJPlacement) {
        log(.showSucceeded)
        showCompletion?(.success([:])) ?? log(.showResultIgnored)
        showCompletion = nil
    }
    
    func contentDidDisappear(_ placement: TJPlacement) {
        log(.didDismiss(error: nil))
        delegate?.didDismiss(self, details: [:], error: nil) ?? log(.delegateUnavailable)
    }
    
    func didClick(_ placement: TJPlacement) {
        // didClick is not being called in TapjoySDK 12.11.0+.
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }

    func placement(_ placement: TJPlacement, didRequestReward request: TJActionRequest?, itemId: String?, quantity: Int32) {
        // See https://dev.tapjoy.com/en/ios-sdk/SDK#id-6-handling-tapjoy-content-action-requests
        log(.didReward)
        delegate?.didReward(self, details: [:]) ?? log(.delegateUnavailable)
    }
}
