//
//  TapJoyAdapterAd.swift
//  ChartboostHeliumAdapterTapJoy
//

import Foundation
import UIKit
import HeliumSdk
import Tapjoy

/// The Helium Tapjoy adapter ad.
final class TapJoyAdapterAd: NSObject, PartnerAd {
    
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
    
    /// The completion handler to notify Helium of ad load completion result.
    var loadCompletion: ((Result<PartnerEventDetails, Error>) -> Void)?
    
    /// The completion handler to notify Helium of ad load completion result.
    var showCompletion: ((Result<PartnerEventDetails, Error>) -> Void)?
    
    /// The Tapjoy SDK placement to load and show ads.
    private let placement: TJPlacement
    
    init(adapter: PartnerAdapter, request: PartnerAdLoadRequest, delegate: PartnerAdDelegate) throws {
        self.adapter = adapter
        self.request = request
        self.delegate = delegate
        if let placement = TJPlacement(
            name: request.partnerPlacement,
            mediationAgent: "chartboost",
            mediationId: nil,
            delegate: nil
        ) {
            self.placement = placement
        } else {
            throw adapter.error(.adCreationFailure(request), description: "Failed to create TJPlacement")
        }
    }
    
    /// Loads an ad.
    /// - parameter viewController: The view controller on which the ad will be presented on. Needed on load for some banners.
    /// - parameter completion: Closure to be performed once the ad has been loaded.
    func load(with viewController: UIViewController?, completion: @escaping (Result<PartnerEventDetails, Error>) -> Void) {
        log(.loadStarted)
        
        loadCompletion = completion
        
        // Configure the placement
        placement.adapterVersion = adapter.adapterVersion
        placement.placementName = request.partnerPlacement
        placement.delegate = self
        placement.videoDelegate = self
        
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
            let error = error(.noAdReadyToShow)
            log(.showFailed(error))
            completion(.failure(error))
            return
        }
        
        // Show ad
        showCompletion = completion
        DispatchQueue.main.async { [self] in
            placement.showContent(with: viewController)
        }
    }
}

extension TapJoyAdapterAd: TJPlacementDelegate {
    
    func requestDidSucceed(_ placement: TJPlacement) {
        if !placement.isContentAvailable {
            let error = error(.loadFailure, description: "No content available")
            log(.loadFailed(error))
            loadCompletion?(.failure(error)) ?? log(.loadResultIgnored)
            loadCompletion = nil
        } else {
            // Do nothing, we complete on contentIsReady()
            log(.delegateCallIgnored)
        }
    }
    
    func requestDidFail(_ placement: TJPlacement, error partnerError: Error?) {
        let error = error(.loadFailure, error: partnerError)
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
        log(.didClick(error: nil))
        delegate?.didClick(self, details: [:]) ?? log(.delegateUnavailable)
    }
}

extension TapJoyAdapterAd: TJPlacementVideoDelegate {
    
    func videoDidComplete(_ placement: TJPlacement) {
        log(.didReward)
        delegate?.didReward(self, details: [:]) ?? log(.delegateUnavailable)
    }
    
    func videoDidFail(_ placement: TJPlacement, error errorMsg: String?) {
        log(.delegateCallIgnored)
    }
}
