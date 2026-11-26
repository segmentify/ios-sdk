//
//  SegmentifyManager.swift
//  Segmentify

import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum SearchCodingKeys: String, CodingKey {
    case search
}

public class SegmentifyManager : NSObject {
    
    static let sdkVersion = SDKVersion.value

    static let tokenKey = "SEGMENTIFY_TOKEN_KEY"
    static let registerKey = "SEGMENTIFY_REGISTER_KEY"
    static let lastRequestDateKey = "SEGMENTIFY_LAST_REQUEST_DATE_KEY"
    
    static let pageViewEventName = "PAGE_VIEW"
    static let productViewEventName = "PRODUCT_VIEW"
    static let basketOperationsEventName = "BASKET_OPERATIONS"
    static let checkoutEventName = "CHECKOUT"
    static let userOperationEventName = "USER_OPERATIONS"
    static let customEventName = "CUSTOM_EVENT"
    static let interactionEventName = "INTERACTION"
    static let searchEventName = "SEARCH"
    static let bannerOperationsEventName = "BANNER_OPERATIONS"
    static let bannerGroupViewEventName = "BANNER_GROUP_VIEW"
    static let internalBannerGroupEventName = "INTERNAL_BANNER_GROUP"
    static let bannerImpressionStep = "impression"
    static let bannerClickStep = "click"
    static let bannerUpdateStep = "update"
    static let userTraitsEventName = "USER_TRAITS"
    static let userIdentifyEventName = "USER_IDENTIFY"
    static let userRegisterCdpEventName = "USER_REGISTER"
    static let userLoginCdpEventName = "USER_LOGIN"
    static let userLogoutCdpEventName = "USER_LOGOUT"
    static let userSubscribeEventName = "USER_SUBSCRIBE"
    static let userUnsubscribeEventName = "USER_UNSUBSCRIBE"
    
    static let customerInformationStep = "customer"
    static let viewBasketStep = "view-basket"
    static let paymentInformationStep = "payment-info"
    static let paymentPurchaseStep = "purchase"
    static let signInStep = "signin"
    static let registerStep = "signup"
    static let logoutStep = "signout"
    static let updateUserStep = "update"
    static let deleteLastSearchStep = "delete_last_search"
    static let impressionStep = "impression"
    static let widgetViewStep = "widget-view"
    static let clickStep = "click"
    static let searchStep = "search"
    static let startIndex = 0
    
    private var params : Dictionary<AnyHashable, Any>?
    private var paramsArr : [[AnyHashable:Any]]?
    private var validStaticItem : Bool = false
    private var staticItems : [AnyHashable : Any]?
    private var recommendationSourceKeys : [String] = []
    private var timeFrameKeys : [String] = []
    private var scoreKeys : [String] = []
    private var keys : [String] = []
    private var itemCounts : [String] = []
    private var dynamicItemsArray : [DynamicItemsModel] = []
    private var recommendationArray = [AnyHashable : Any]()
    private var searcResponseProductsArray = [ProductRecommendationModel]()
    private var recommendations :[RecommendationModel] = []
    private var searchResponse = SearchModel()
    private var facetedResponse = SegmentifyManager.createEmptyFacetedResponse()
    private var currentKey : String?
    private var type : String?
    private var staticItemsArrayCount : Int = Int()
    private var currentNewArray : [RecommendationModel]?
    private var key : String = String()
    private var newRecommendationArray : [RecommendationModel] = []
    private var clickedBanners: [ClickedBannerObject] = []
    private lazy var cdpEventService: CdpEventService = CdpEventService(
        sessionResolver: self,
        requestBuilder: self,
        profileStore: SecureUserProfileStore(),
        dispatcher: { request, success, failure in
            SegmentifyConnectionManager.sharedInstance.request(
                requestModel: request,
                success: { _ in success() },
                failure: { _ in failure() }
            )
        }
    )
    
    private var testStaticProducts : [AnyHashable:Any]?
    private var testOtherProducts : [AnyHashable:Any]?
    private var minusIndex : Int?
    
    private var currentRecModel = RecommendationModel()
    private var products : [ProductRecommendationModel] = []
    private static var segmentifySharedInstance: SegmentifyManager?
    private var sessionWaiters: [SessionWaiter] = []
    private var isRequestingSession = false
    private let sessionLock = NSLock()
    private typealias WaitingEvent = (
        snapshot: EventSnapshot,
        callback: ((_ recommendation: [RecommendationModel]) -> Void)?,
        onFailure: ((SegmentifyError) -> Void)?
    )
    private var waitingEvents: [WaitingEvent] = []
    /// The `onError` of the call being made on this thread; see `reportingErrors`.
    /// Kept per thread so that calls made on different threads cannot take or
    /// clear each other's handler.
    private var pendingErrorHandler: ((SegmentifyError) -> Void)? {
        get {
            (Thread.current.threadDictionary[SegmentifyManager.pendingErrorHandlerKey] as? ErrorHandlerBox)?.handler
        }
        set {
            if let handler = newValue {
                Thread.current.threadDictionary[SegmentifyManager.pendingErrorHandlerKey] = ErrorHandlerBox(handler)
            } else {
                Thread.current.threadDictionary.removeObject(forKey: SegmentifyManager.pendingErrorHandlerKey)
            }
        }
    }
    private static let pendingErrorHandlerKey = "com.segmentify.sdk.pendingErrorHandler"
    static let maxWaitingEvents = 50
    private var eventRequest = SegmentifyRegisterRequest()
    private static let setup = ConfigModel()
    // log status variable. Default: true
    static var logStatus: Bool = true
    static var _sessionKeepSecond: Int = 86400
    /// Waits between attempts to fetch the user id and session id.
    static let defaultSessionRetryDelays: [TimeInterval] = [1, 3]
    static var sessionRetryDelays: [TimeInterval] = defaultSessionRetryDelays
    // set log status
    public class func logStatus(isVisible: Bool) -> Bool{
        logStatus = isVisible
        return isVisible
    }
    
    public class func setSessionKeepSecond(sessionKeepSecond: Int) -> Int{
        _sessionKeepSecond = sessionKeepSecond
        return sessionKeepSecond
    }

    /// Same as `config`: updates the shared manager, which keeps its state.
    public class func setConfig(apiKey: String,dataCenterUrl : String, subDomain : String) {
        configure(apiKey: apiKey, dataCenterUrl: dataCenterUrl, subDomain: subDomain)
    }
    
    public class func setPushConfig(dataCenterUrlPush : String) {
        SegmentifyManager.setup.dataCenterUrlPush = dataCenterUrlPush        
    }
    
    public class func sharedManager() -> SegmentifyManager {
        if segmentifySharedInstance == nil {
            segmentifySharedInstance = SegmentifyManager.init()
        }
        return segmentifySharedInstance!
    }
    
    public class func config(appkey: String, dataCenterUrl: String, subDomain: String) {
        configure(apiKey: appkey, dataCenterUrl: dataCenterUrl, subDomain: subDomain)
    }

    /// The one place the configuration is set. A manager the app took before
    /// configuring, or is still holding, is the one that gets it.
    private class func configure(apiKey: String, dataCenterUrl: String, subDomain: String) {
        setup.apiKey = apiKey
        setup.dataCenterUrl = dataCenterUrl
        setup.subDomain = subDomain
        sharedManager().applyConfiguration()
    }

    /// Copies the configuration into the request every event starts from.
    private func applyConfiguration() {
        eventRequest.apiKey = SegmentifyManager.setup.apiKey ?? ""
        eventRequest.subdomain = SegmentifyManager.setup.subDomain ?? ""
        eventRequest.dataCenterUrl = SegmentifyManager.setup.dataCenterUrl ?? ""
    }
    
    var debugMode = false {
        didSet {
            SegmentifyConnectionManager.sharedInstance.debugMode = debugMode
        }
    }
    
    override init() {
        super.init()
        self.eventRequest = SegmentifyRegisterRequest()
        // Taken before config: config fills this in later; events sent
        // meanwhile fail with SegmentifyNetworkError.notConfigured.
        applyConfiguration()

        eventRequest.sdkVersion = SegmentifyManager.sdkVersion
        eventRequest.token = SegmentifyTools.retrieveUserDefaults(userKey: SegmentifyManager.tokenKey) as? String
        
        if let lastRegister = SegmentifyTools.retrieveUserDefaults(userKey: SegmentifyManager.registerKey) as? String,
           let extra = SegmentifyRegisterRequest(withJsonString: lastRegister)?.extra {
            eventRequest.extra = extra
        }
        self.currentKey = "RECOMMENDATION_SOURCE_STATIC_ITEMS"

        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeDeactive),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        #endif
    }
    
    deinit {
            #if canImport(UIKit)
            NotificationCenter.default.removeObserver(
                self,
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
            NotificationCenter.default.removeObserver(
                self,
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
            #endif
        }
    
    @objc private func applicationDidBecomeActive() {
            print("applicationDidBecomeActive")
            self.getUserIdAndSessionIdRequest {
                print("received user id and session id")
            }
        }

        @objc private func applicationDidBecomeDeactive() {
            print("applicationDidBecomeDeactive")
            self.eventRequest.sessionID = nil
        }
    
    // MARK: Request Builders
    func setIDAndSendEvent() {
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            
        }
        
        if self.eventRequest.sessionID == nil {
            self.sendWhenSessionIsReady(EventSnapshot(of: eventRequest), callback: nil)
        } else {
            self.sendEvent(callback: { (response: [RecommendationModel]) in
            })
        }
    }
    
    func setIDAndSendEventWithCallback(callback: @escaping (_ recommendation: [RecommendationModel]) -> Void) {
        let onFailure = takeErrorHandler()
        if self.eventRequest.sessionID == nil {
            self.sendWhenSessionIsReady(EventSnapshot(of: eventRequest), callback: callback, onFailure: onFailure)
        } else {
            self.sendEvent(onFailure: thenClearData(onFailure), callback: { (response: [RecommendationModel]) in
                callback(response)
                self.clearData()
                
            })
        }
    }
    
    /// Sends `snapshot` when given, otherwise the shared request as it is right now.
    /// Every call answers with a result object of its own.
    func sendSearchEvent(snapshot: EventSnapshot? = nil, onFailure: ((SegmentifyError) -> Void)? = nil, callback: @escaping (_ recommendation: SearchModel) -> Void) {
        dispatchEvent(snapshot: snapshot, success: {(response: [String:AnyObject]) in
            // The parsing helpers fill `searchResponse`; start from an empty one so
            // that nothing of an earlier search is left in this result.
            self.searchResponse = SearchModel()

            guard let searches = response["search"] as? [[Dictionary<AnyHashable,Any>]] else {
                self.logResponseProblem("no search response, statusCode: \(String(describing: response["statusCode"]))")
                callback(self.searchResponse)
                return
            }
            
            if(searches.isEmpty){
                print("error : search response is not valid or empty")
                callback(self.searchResponse)
                return
            }
            else{
                for (_, obj) in searches[0].enumerated() {
                    
                    guard let products = obj["products"] as? [Dictionary<AnyHashable,Any>] else {
                        callback(self.searchResponse)
                        return
                    }
                    self.createSearchProducts(products: products)
                    
                    guard let campaign = obj["campaign"] as?  Dictionary<AnyHashable, Any> else {
                        callback(self.searchResponse)
                        return
                    }
                    self.createSearchCampaign(campaignParam: campaign)
                    
                    if let _categoryProducts = obj["categoryProducts"] as?  Dictionary<AnyHashable, Any>{
                        self.createCategoryProducts(categoryProducts: _categoryProducts)
                    }
                    
                    if let _brandProducts = obj["brandProducts"] as?  Dictionary<AnyHashable, Any>{
                        self.createBrandProducts(brandProducts: _brandProducts)
                    }
                    
                    if let _keywordProducts = obj["keywords"] as?  Dictionary<AnyHashable, Any>{
                        self.createKeywordProducts(keywordProducts: _keywordProducts)
                    }
                    
                    if let _searchCategories = obj["categories"] as?  Dictionary<AnyHashable, Any>{
                        self.createSearchCategories(categories: _searchCategories)
                    }
                    
                    if let _searchBrands = obj["brands"] as?  Dictionary<AnyHashable, Any>{
                        self.createSearchBrands(brands: _searchBrands)
                    }
                    
                    if let _lastSearches = obj["lastSearches"] as? [String]{
                        self.createLastSearches(lastSearches: _lastSearches)
                    }
                    
                }
                
                var insId : String = String()
                if let instanceId = self.searchResponse.campaign?.instanceId as String? {
                    insId = instanceId
                }
                let interactionId = "static"
                
                if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                    self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
                }
                self.sendImpression(instanceId: insId, interactionId: interactionId)
                self.sendWidgetView(instanceId: insId, interactionId: interactionId)

            }
            
            callback(self.searchResponse)
            
        }, failure: {(error: Error) in
            if (self.debugMode) {
                print("Request failed : \(error)")
            }
            if let onFailure = onFailure {
                onFailure(SegmentifyError.from(error))
            } else {
                callback(SegmentifyManager.failedSearchResult())
            }
        })
    }
    
    /// What a search answers with when it could not be completed.
    private static func failedSearchResult() -> SearchModel {
        let result = SearchModel()
        result.errorString = "error"
        return result
    }

    private static func createEmptyFacetedResponse() -> FacetedResponseModel {
        FacetedResponseModel(
            facets: nil,
            meta: nil,
            contents: nil,
            banners: nil,
            meanings: nil,
            products: [],
            executable: nil,
            instanceId: nil
        )
    }

    private func makeEmptyFacetedResponse() -> FacetedResponseModel {
        Self.createEmptyFacetedResponse()
    }

    private func parseFacetedSearchResponse(_ response: [String: AnyObject]) -> FacetedResponseModel? {
        guard let searches = response["search"] as? [[Dictionary<AnyHashable, Any>]],
              let searchResults = searches.first,
              !searchResults.isEmpty else {
            return nil
        }

        for obj in searchResults {
            guard obj["products"] is [Any] else {
                continue
            }
            guard JSONSerialization.isValidJSONObject(obj),
                  let jsonData = try? JSONSerialization.data(withJSONObject: obj),
                  let decoded = try? FacetedResponseModel(data: jsonData) else {
                continue
            }
            return decoded
        }

        return nil
    }

    private func deliverFacetedSearchCallback(
        _ callback: @escaping (_ recommendation: FacetedResponseModel) -> Void,
        response: FacetedResponseModel
    ) {
        DispatchQueue.main.async {
            callback(response)
        }
    }

    /// Sends `snapshot` when given, otherwise the shared request as it is right now.
    func sendSearchFacetedEvent(snapshot: EventSnapshot? = nil, onFailure: ((SegmentifyError) -> Void)? = nil, callback: @escaping (_ recommendation: FacetedResponseModel) -> Void) {
        dispatchEvent(snapshot: snapshot, success: {(response: [String:AnyObject]) in
            if let decoded = self.parseFacetedSearchResponse(response) {
                self.facetedResponse = decoded
                self.deliverFacetedSearchCallback(callback, response: decoded)
                return
            }

            if let statusCode = response["statusCode"] {
                print("error : \(statusCode)")
            } else {
                print("error : search response is not valid or empty")
            }
            self.deliverFacetedSearchCallback(callback, response: self.makeEmptyFacetedResponse())

        }, failure: {(error: Error) in
            if self.debugMode {
                print("Request failed : \(error)")
            }
            if let onFailure = onFailure {
                onFailure(SegmentifyError.from(error))
                return
            }
            self.deliverFacetedSearchCallback(callback, response: self.makeEmptyFacetedResponse())
        })
    }
    
    /// Sends `snapshot` when given, otherwise the shared request as it is right now.
    private func dispatchEvent(
        snapshot: EventSnapshot?,
        success: @escaping (_ response: [String:AnyObject]) -> Void,
        failure: @escaping (_ error: Error) -> Void
    ) {
        if let snapshot = snapshot {
            SegmentifyConnectionManager.sharedInstance.request(requestModel: snapshot, success: success, failure: failure)
        } else {
            SegmentifyConnectionManager.sharedInstance.request(requestModel: eventRequest, success: success, failure: failure)
        }
    }

    /// A failure goes to `onFailure` when there is one, otherwise `callback`
    /// answers with an empty result.
    func sendEvent(snapshot: EventSnapshot? = nil, onFailure: ((SegmentifyError) -> Void)? = nil, callback: @escaping (_ recommendation: [RecommendationModel]) -> Void) {
        dispatchEvent(snapshot: snapshot, success: {(response: [String:AnyObject]) in
            
            self.recommendations.removeAll()

            // Whatever the body looks like, the host app hears back exactly once.
            guard let responses = response["responses"] as? [[Dictionary<AnyHashable,Any>]], !responses.isEmpty else {
                self.logResponseProblem("no recommendation responses, statusCode: \(String(describing: response["statusCode"]))")
                callback(self.recommendations)
                return
            }
            do {
                // An item that is not a well-formed product recommendation is
                // skipped; it must not discard the items after it.
                for (_, obj) in responses[0].enumerated() {
                    self.minusIndex = Int()
                    guard let params = obj["params"] as? Dictionary<AnyHashable, Any> else {
                        continue
                    }
                    self.params = params
                    
                    self.type = obj["type"] as? String
                    
                    guard self.type == "recommendProducts"  else {
                        self.logResponseProblem("skipping response item of type \(self.type ?? "nil")")
                        continue
                    }
                    
                    guard let dynamicItems = self.params!["dynamicItems"] as? String else {
                        self.logResponseProblem("params['dynamicItems'] or params['staticItems'] is not valid")
                        continue
                    }
                    
                    guard let dynamicDic = SegmentifyTools.convertStringToDictionary(text: dynamicItems) else {
                        self.logResponseProblem("cannot convert string to json")
                        continue
                    }
                    
                    guard let recommendedProducts = self.params!["recommendedProducts"] as? Dictionary<AnyHashable, Any> else {
                        self.logResponseProblem("params['recommendedProducts'] is not valid")
                        continue
                    }
                    self.recommendationArray = recommendedProducts
                    
                    guard let notificationTitle = self.params!["notificationTitle"] as? String else {
                        self.logResponseProblem("params['notificationTitle'] is not valid")
                        continue
                    }
                    
                    guard let staticItems = self.params!["staticItems"] as? String else {
                        self.logResponseProblem("params['dynamicItems'] or params['staticItems'] is not valid")
                        continue
                    }
                    
                    guard let staticItemsDic = SegmentifyTools.convertStringToDictionary(text: staticItems) else {
                        self.logResponseProblem("cannot convert string to json")
                        continue
                    }

                    var insId : String = String()
                    var interId : String = String()
                    if let instanceId = self.params!["instanceId"] as? String {
                        insId = instanceId
                    }
                    
                    if let interactionId = self.params!["actionId"] as? String {
                        interId = interactionId
                    }
                    
                    if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                        self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
                    }
                    self.sendImpression(instanceId: insId, interactionId: interId)

                    for object in dynamicDic {
                        let dynObj = DynamicItemsModel()
                        var key = String()
                        if let recommendationSource = object["recommendationSource"] as? String {
                            self.recommendationSourceKeys.append(recommendationSource)
                            dynObj.recommendationSource = recommendationSource
                            key = recommendationSource
                        }

                        // The backend sends the count as a string; accept a number too.
                        let itemCount = (object["itemCount"] as? String).flatMap { Int($0) }
                            ?? (object["itemCount"] as? NSNumber)?.intValue
                        if let itemCount = itemCount {
                            self.itemCounts.append(String(itemCount))
                            dynObj.itemCount = itemCount
                        }

                        if let timeFrame = object["timeFrame"] as? String {
                            self.timeFrameKeys.append(timeFrame)
                            dynObj.timeFrame = timeFrame
                            key = key + "|\(timeFrame)"
                            if let score = object["score"] as? String {
                                self.scoreKeys.append(score)
                                dynObj.score = score
                                key = key + "|\(score)"
                            }
                        }
                        //let key = "\(object["recommendationSource"]!)|\(object["timeFrame"]!)"
                        if key != "" {
                            dynObj.key = key
                            self.keys.append(key)
                            self.dynamicItemsArray.append(dynObj)
                        }
                    }
                    if staticItemsDic.count > 0 {
                        self.validStaticItem = true
                        self.getStaticItemsArray(notificationTitle: notificationTitle, recommendedProducts: recommendedProducts,interactionId: interId,impressionId : insId)
                    }
                    self.getRecommendations(notificationTitle: notificationTitle, recommendedProducts: recommendedProducts, staticItems: nil, keys: self.keys,interactionId: interId,impressionId : insId)
                }
            }
            callback(self.recommendations)
        }, failure: {(error: Error) in
            if (self.debugMode) {
                print("Request failed : \(error)")
            }
            // Never hand back what an earlier response left in the shared array.
            self.recommendations.removeAll()
            if let onFailure = onFailure {
                onFailure(SegmentifyError.from(error))
            } else {
                callback([])
            }
        })
    }
    
    private func logResponseProblem(_ message: String) {
        if SegmentifyManager.logStatus {
            print("Segmentify: \(message)")
        }
    }

    private func clearData() {
        self.params?.removeAll()
        self.paramsArr?.removeAll()
        self.validStaticItem = false
        self.staticItems?.removeAll()
        self.recommendationSourceKeys.removeAll()
        self.timeFrameKeys.removeAll()
        self.keys.removeAll()
        self.itemCounts.removeAll()
        self.dynamicItemsArray.removeAll()
        self.recommendationArray.removeAll()
        self.recommendations.removeAll()
        self.searchResponse = SearchModel()
        self.facetedResponse = Self.createEmptyFacetedResponse()
        self.currentKey = nil
        self.type = nil
        self.staticItemsArrayCount = Int()
        self.currentNewArray?.removeAll()
        self.key = String()
        self.newRecommendationArray.removeAll()
        self.currentRecModel = RecommendationModel()
        self.products.removeAll()
    }
    
    private func getStaticItemsArray(notificationTitle: String, recommendedProducts: Dictionary<AnyHashable, Any>,interactionId: String!,impressionId : String!) {
        self.currentKey = "RECOMMENDATION_SOURCE_STATIC_ITEMS"
        if dynamicItemsArray.count > 0 {
            for dynObj in dynamicItemsArray {
                if let products = recommendedProducts[self.currentKey!] as? [[AnyHashable:Any]] {
                    if products.count > 0 {
                        self.createRecomendation(title: notificationTitle, itemCount: dynObj.itemCount ?? products.count, products: products,interactionId: interactionId,impressionId: impressionId)
                        self.staticItemsArrayCount = (self.currentRecModel.products?.count)!
                    }
                }
            }
        }
    }
    
    private func getRecommendations(notificationTitle: String, recommendedProducts: Dictionary<AnyHashable, Any>, staticItems: Dictionary<AnyHashable, Any>?,  keys : [String],interactionId : String!,impressionId : String!) {
        if validStaticItem {
            self.recommendationArray["products"] = staticItems as AnyObject
        }
        var newProdArray = [ProductRecommendationModel]()
        
        if dynamicItemsArray.count > 0 {
            for dynObj in dynamicItemsArray {
                
                self.currentKey = dynObj.key
                if let products = recommendedProducts[dynObj.key!] as? [[AnyHashable:Any]] {
                    if products.count > 0 {
                        
                        self.createRecomendation(title: notificationTitle, itemCount: dynObj.itemCount ?? products.count, products: products,interactionId: interactionId,impressionId: impressionId)
                        var counter = 0
                        for product in currentRecModel.products!{
                            if newProdArray.contains(where: {$0.productId==product.productId}){ }
                            else {
                                if counter < dynObj.itemCount ?? products.count {
                                    if( dynObj.recommendationSource == "RECOMMENDATION_SOURCE_LAST_VISITED" ||
                                        !checkIfItemRecommendedBefore(item: product)) {
                                        newProdArray.append(product)
                                        counter = counter + 1
                                    }
                                }
                            }
                        }
                        self.products.removeAll()
                        currentRecModel = RecommendationModel()
                    }
                }
            }
            let newRecModel = RecommendationModel()
            newRecModel.notificationTitle = notificationTitle
            newRecModel.products = newProdArray
            newRecModel.instanceId = impressionId
            newRecModel.interactionId = interactionId
            recommendations.append(newRecModel)
        } else if validStaticItem {
            if let products = recommendedProducts[self.currentKey!] as? [[AnyHashable:Any]] {
                if products.count > 0 {
                    self.createRecomendation(title: notificationTitle, itemCount: products.count, products: products,interactionId: interactionId,impressionId: impressionId)
                    for product in currentRecModel.products!{
                        if newProdArray.contains(where: {$0.productId==product.productId}){ }
                        else {
                            if(!checkIfItemRecommendedBefore(item: product)) {
                                newProdArray.append(product)
                            }
                        }
                    }
                    self.products.removeAll()
                    currentRecModel = RecommendationModel()
                }
            }
            let newRecModel = RecommendationModel()
            newRecModel.notificationTitle = notificationTitle
            newRecModel.products = newProdArray
            newRecModel.instanceId = impressionId
            newRecModel.interactionId = interactionId
            recommendations.append(newRecModel)
        }
    }
    
    private func checkIfItemRecommendedBefore(item : ProductRecommendationModel) -> Bool {
        for model in self.recommendations {
            for recoItem in model.products! {
                if(recoItem.productId==item.productId) {
                    return true;
                }
            }
        }
        return false;
    }
    
    private func createRecomendation(title:String, itemCount:Int, products:[[AnyHashable:Any]], interactionId:String!, impressionId:String!) {
        for (_, obj) in products.enumerated() {
            let proObj = ProductRecommendationModel()
            
            if let noUpdate = obj["noUpdate"] {
                proObj.noUpdate = noUpdate as? Bool
            }
            if let labels = obj["labels"] {
                proObj.labels = labels as? [String]
            }
            if let sizes = obj["sizes"] {
                proObj.sizes = sizes as? [String]
            }
            if let colors = obj["colors"] {
                proObj.colors = colors as? [String]
            }
            if let gender = obj["gender"] {
                proObj.gender = gender as? String
            }
            if let categories = obj["categories"] {
                proObj.categories = categories as? [String]
            }
            if let category = obj["category"] {
                proObj.category = category as? [String]
            }
            if let imageXL = obj["imageXL"] {
                proObj.imageXL = imageXL as? String
            }
            if let imageL = obj["imageL"] {
                proObj.imageL = imageL as? String
            }
            if let imageM = obj["imageM"] {
                proObj.imageM = imageM as? String
            }
            if let imageS = obj["imageS"] {
                proObj.imageS = imageS as? String
            }
            if let imageXS = obj["imageXS"] {
                proObj.imageXS = imageXS as? String
            }
            if let mUrl = obj["mUrl"] {
                proObj.mUrl = mUrl as? String
            }
            if let url = obj["url"] {
                proObj.url = url as? String
            }
            if let brand = obj["brand"] {
                proObj.brand = brand as? String
            }
            if let name = obj["name"] {
                proObj.name = name as? String
            }
            if let productId = obj["productId"] {
                proObj.productId = productId as? String
            }
            if let image = obj["image"] {
                proObj.image = image as? String
            }
            if let inStock = obj["inStock"] {
                proObj.inStock = inStock as? Bool
            }
            if let price = obj["price"] {
                proObj.price = price as? NSNumber
            }
            if let oldPrice = obj["oldPrice"] {
                proObj.oldPrice = oldPrice as? NSNumber
            }
            if let specialPrice = obj["specialPrice"] {
                proObj.specialPrice = specialPrice as? NSNumber
            }
            if let priceText = obj["priceText"] {
                proObj.priceText = priceText as? String
            }
            if let oldPriceText = obj["oldPriceText"] {
                proObj.oldPriceText = oldPriceText as? String
            }
            if let specialPriceText = obj["specialPriceText"] {
                proObj.specialPriceText = specialPriceText as? String
            }
            if let params = obj["params"]{
                proObj.params = params as? [String:AnyObject]
            }
            if self.products.contains(where: {$0.productId == proObj.productId}) {
                minusIndex = minusIndex! - 1
            } else {
                addProduct(proObj: proObj)
                self.currentRecModel.products = self.products
            }
        }
        
        self.currentRecModel.instanceId = impressionId
        self.currentRecModel.interactionId = interactionId
        self.currentRecModel.notificationTitle = title
    }
    
    private func createSearchCampaign(campaignParam: Dictionary<AnyHashable, Any>){
        let campaign = SearchCampaignModel()
        
        if let searchAssetTexts = campaignParam["stringSearchAssetTextMap"] {
            var textMap = [String:SearchAssetTextModel]()
            for (key, val) in (searchAssetTexts as? [String:AnyObject]) ?? [:] {
                guard let assets = val as? Dictionary<AnyHashable,Any> else {
                    continue
                }
                let assetTexts = SearchAssetTextModel()
                
                if let popularProductsText = assets["popularProductsText"] as? String {
                    assetTexts.popularProductsText = popularProductsText
                }
                if let mobileCancelText = assets["mobileCancelText"] as? String {
                    assetTexts.mobileCancelText = mobileCancelText
                }
                if let notFoundText = assets["notFoundText"] as? String {
                    assetTexts.notFoundText = notFoundText
                }
                textMap[key] = assetTexts
            }
            campaign.stringSearchAssetTextMap = textMap
            
        }
        if let instanceId = campaignParam["instanceId"] {
            campaign.instanceId = instanceId as? String
        }
        if let name = campaignParam["name"] {
            campaign.name = name as? String
        }
        if let status = campaignParam["status"] {
            campaign.status = status as? String
        }
        if let devices = campaignParam["devices"] {
            campaign.devices = devices as? [String]
        }
        if let searchDelay = campaignParam["searchDelay"] {
            campaign.searchDelay = searchDelay as? Int
        }
        if let minCharacterCount = campaignParam["minCharacterCount"] {
            campaign.minCharacterCount = minCharacterCount as? Int
        }
        if let searchUrlPrefix = campaignParam["searchUrlPrefix"] {
            campaign.searchUrlPrefix = searchUrlPrefix as? String
        }
        if let mobileItemCount = campaignParam["mobileItemCount"] {
            campaign.mobileItemCount = mobileItemCount as? Int
        }
        self.searchResponse.campaign = campaign
    }
    
    private func createSearchProducts(products:[[AnyHashable:Any]]) {
        self.searcResponseProductsArray = products.map { self.makeSearchProduct(from: $0) }
        self.searchResponse.products = self.searcResponseProductsArray
    }

    private func makeSearchProduct(from obj: [AnyHashable:Any]) -> ProductRecommendationModel {
        let proObj = ProductRecommendationModel()
        
        if let noUpdate = obj["noUpdate"] {
            proObj.noUpdate = noUpdate as? Bool
        }
        if let currency = obj["currency"] {
            proObj.currency = currency as? String
        }
        if let language = obj["language"] {
            proObj.language = language as? String
        }
        if let oldPriceText = obj["oldPriceText"] {
            proObj.oldPriceText = oldPriceText as? String
        }
        if let priceText = obj["priceText"] {
            proObj.priceText = priceText as? String
        }
        if let labels = obj["labels"] {
            proObj.labels = labels as? [String]
        }
        if let sizes = obj["sizes"] {
            proObj.sizes = sizes as? [String]
        }
        if let colors = obj["colors"] {
            proObj.colors = colors as? [String]
        }
        if let gender = obj["gender"] {
            proObj.gender = gender as? String
        }
        if let categories = obj["categories"] {
            proObj.categories = categories as? [String]
        }
        if let category = obj["category"] {
            proObj.category = category as? [String]
        }
        if let imageXL = obj["imageXL"] {
            proObj.imageXL = imageXL as? String
        }
        if let imageL = obj["imageL"] {
            proObj.imageL = imageL as? String
        }
        if let imageM = obj["imageM"] {
            proObj.imageM = imageM as? String
        }
        if let imageS = obj["imageS"] {
            proObj.imageS = imageS as? String
        }
        if let imageXS = obj["imageXS"] {
            proObj.imageXS = imageXS as? String
        }
        if let mUrl = obj["mUrl"] {
            proObj.mUrl = mUrl as? String
        }
        if let url = obj["url"] {
            proObj.url = url as? String
        }
        if let brand = obj["brand"] {
            proObj.brand = brand as? String
        }
        if let name = obj["name"] {
            proObj.name = name as? String
        }
        if let productId = obj["productId"] {
            proObj.productId = productId as? String
        }
        if let image = obj["image"] {
            proObj.image = image as? String
        }
        if let inStock = obj["inStock"] {
            proObj.inStock = inStock as? Bool
        }
        if let price = obj["price"] {
            proObj.price = price as? NSNumber
        }
        if let oldPrice = obj["oldPrice"] {
            proObj.oldPrice = oldPrice as? NSNumber
        }
        if let params = obj["params"]{
            proObj.params = params as? [String:AnyObject]
        }
        return proObj
    }

    /// Maps `{ "group name": [product, ...] }`. Entries whose value is not a list of
    /// product objects are skipped.
    private func makeProductGroups(from groups: Dictionary<AnyHashable, Any>) -> [String:[ProductRecommendationModel]] {
        var result = [String:[ProductRecommendationModel]]()
        for (key, val) in groups {
            guard let name = key as? String, let products = val as? [[AnyHashable:Any]] else {
                continue
            }
            result[name] = products.map { self.makeSearchProduct(from: $0) }
        }
        return result
    }

    /// Maps `{ "name": "value" }`. Entries whose value is not a string are skipped.
    private func makeStringMap(from values: Dictionary<AnyHashable, Any>) -> [String:String] {
        var result = [String:String]()
        for (key, val) in values {
            guard let name = key as? String, let value = val as? String else {
                continue
            }
            result[name] = value
        }
        return result
    }

    private func createCategoryProducts(categoryProducts: Dictionary<AnyHashable, Any>){
        self.searchResponse.categoryProducts = makeProductGroups(from: categoryProducts)
    }

    private func createBrandProducts(brandProducts: Dictionary<AnyHashable, Any>){
        self.searchResponse.brandProducts = makeProductGroups(from: brandProducts)
    }

    private func createKeywordProducts(keywordProducts: Dictionary<AnyHashable, Any>){
        self.searchResponse.keywords = makeProductGroups(from: keywordProducts)
    }

    private func createSearchCategories(categories: Dictionary<AnyHashable, Any>){
        self.searchResponse.categories = makeStringMap(from: categories)
    }

    private func createSearchBrands(brands: Dictionary<AnyHashable, Any>){
        self.searchResponse.brands = makeStringMap(from: brands)
    }

    private func createLastSearches(lastSearches: [String]){
        self.searchResponse.lastSearches.removeAll()
        var _lastSearches = [String]()
    
        for(key) in lastSearches {
            _lastSearches.append(key)
        }
        
        self.searchResponse.lastSearches = _lastSearches
    }
    
    private func addProduct(proObj : ProductRecommendationModel) {
        if !self.products.contains(where: {$0.productId == proObj.productId}) {
            self.products.append(proObj)
        }
    }

    open func sendNotification(segmentifyObject : NotificationModel) {
        
        if (segmentifyObject.userId == nil) {
            self.getUserIdAndSessionIdRequest( success: { () -> Void in
                segmentifyObject.userId = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
            })
        }
        
        if(segmentifyObject.type == NotificationType.PERMISSION_INFO){
            
            let deviceToken = segmentifyObject.deviceToken
            guard  deviceToken != nil else {
                print("Error - you must fill deviceToken before accessing sendNotification event")
                return
            }
            
        }
        if(SegmentifyManager.setup.dataCenterUrlPush == nil || SegmentifyManager.setup.dataCenterUrlPush == ""){
            print("Error - you must set dataCenterUrlPush in setConfig before accessing sendNotification event")
            return
        }
        
        guard var request = pushRequest(path: "/native/subscription/push") else {
            return
        }
        request.httpBody = try? JSONEncoder().encode(segmentifyObject)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let _ = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
        }
        task.resume()
    }

    open func sendNotificationInteraction(segmentifyObject : NotificationModel) {
        
        if(SegmentifyManager.setup.dataCenterUrlPush == nil || SegmentifyManager.setup.dataCenterUrlPush == ""){
            print("Error - you must set dataCenterUrlPush in setConfig before accessing sendNotificationInteraction event")
            return
        }
        
        if( segmentifyObject.type == NotificationType.VIEW){
            let instanceId = segmentifyObject.instanceId
            guard instanceId != nil  else {
                print("Error - you must fill instanceId or deviceToken before accessing sendNotification view event")
                return
            }
        }

        if(segmentifyObject.type == NotificationType.CLICK){
            let instanceId = segmentifyObject.instanceId
            
            guard instanceId != nil  else {
                print("Error - you must fill instanceId or deviceToken before accessing sendNotification click event")
                return
            }
            

            UserDefaults.standard.set(segmentifyObject.instanceId, forKey: "SEGMENTIFY_PUSH_CAMPAIGN_ID")
            
            let model  = InteractionModel()
            model.instanceId = instanceId
            model.interactionId = instanceId

            sendClick(segmentifyObject: model)
        }

        guard var request = pushRequest(path: "/native/interaction/notification") else {
            return
        }
        request.httpBody = try? JSONEncoder().encode(segmentifyObject)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let _ = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
        }
        task.resume()
    }

    /// A POST to the push endpoint `path`, or nil when the SDK is not configured
    /// for push yet. A push can be handled before the app configures the SDK.
    private func pushRequest(path: String) -> URLRequest? {
        guard let dataCenter = SegmentifyManager.setup.dataCenterUrlPush, !dataCenter.isEmpty,
              let apiKey = SegmentifyManager.setup.apiKey, !apiKey.isEmpty,
              let url = URL(string: dataCenter + path + "?apiKey=" + apiKey) else {
            print("Error - SegmentifyManager.config and setPushConfig must be called before sending push events")
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        SegmentifyUserAgent.apply(to: &request)
        return request
    }

    open func getTrackingParameters()->UtmModel{
        return UtmModel()
    }

    //EVENTS
    //Register Event
    open func sendUserRegister(segmentifyObject: UserModel) {
        
        eventRequest.eventName = SegmentifyManager.userOperationEventName
        eventRequest.userOperationStep = SegmentifyManager.registerStep
        
        
        let email = segmentifyObject.email
        let username = segmentifyObject.externalId
        
        guard email != nil || username != nil else {
            print("Error - you must fill userId or email before accessing sendUserLogout event")
            return
        }
        
        UserDefaults.standard.set(email, forKey: "SEGMENTIFY_EMAIL")
        UserDefaults.standard.set(username, forKey: "SEGMENTIFY_USERNAME")

        eventRequest.instanceId = nil
        
        
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }

        if segmentifyObject.lang != nil {
            eventRequest.lang = segmentifyObject.lang
        }
        if segmentifyObject.currency != nil {
            eventRequest.currency = segmentifyObject.currency
        }

        setIDAndSendEvent()
    }

    // User Traits Event
    @available(*, deprecated, message: "Use userTraits(_:) instead. This legacy API forwards to the CDP USER_TRAITS pipeline.")
    open func sendUserTraits(segmentifyObject: UserTraitsModel) {
        userTraits(segmentifyObject.properties)
    }

    @available(*, deprecated, message: "Use userTraits(_:) instead. This legacy API forwards to the CDP USER_TRAITS pipeline.")
    open func sendUserTraits(properties: [String: Any]) {
        userTraits(properties)
    }

    // MARK: - CDP User Events

    open func userTraits(_ params: CdpEventsPayload) {
        guard let configuredParams = withConsentDefaults(params) else { return }
        cdpEventService.send(name: SegmentifyManager.userTraitsEventName, properties: configuredParams)
    }

    open func identifyUser(_ params: CdpEventsPayload, completion: (() -> Void)? = nil) {
        guard let configuredParams = withConsentDefaults(params) else {
            completion?()
            return
        }

        cdpEventService.identify(properties: configuredParams, completion: completion)
    }

    open func registerUser(_ params: CdpEventsPayload) {
        guard let configuredParams = withConsentDefaults(params) else { return }
        cdpEventService.send(name: SegmentifyManager.userRegisterCdpEventName, properties: configuredParams)
    }

    open func loginUser(_ params: CdpEventsPayload) {
        guard let configuredParams = withConsentDefaults(params) else { return }
        cdpEventService.send(name: SegmentifyManager.userLoginCdpEventName, properties: configuredParams)
    }

    open func logoutUser(_ params: CdpEventsPayload) {
        guard let configuredParams = withConsentDefaults(params) else { return }
        cdpEventService.send(name: SegmentifyManager.userLogoutCdpEventName, properties: configuredParams)
    }

    open func subscribeUser(_ params: CdpSubscribePayload) {
        cdpEventService.send(
            name: SegmentifyManager.userSubscribeEventName,
            properties: params.toDictionary()
        )
    }

    open func unsubscribeUser(_ params: CdpUnsubscribePayload) {
        cdpEventService.send(
            name: SegmentifyManager.userUnsubscribeEventName,
            properties: params.toDictionary()
        )
    }

    
    //Login Event
    open func sendUserLogin(segmentifyObject : UserModel) {
        
        eventRequest.eventName = SegmentifyManager.userOperationEventName
        eventRequest.userOperationStep = SegmentifyManager.signInStep
        
        let email = segmentifyObject.email
        let username = segmentifyObject.externalId
        
        guard email != nil || username != nil else {
            print("Error - you must fill userId or email before accessing sendUserLogin event")
            return
        }

        UserDefaults.standard.set(email, forKey: "SEGMENTIFY_EMAIL")
        UserDefaults.standard.set(username, forKey: "SEGMENTIFY_USERNAME")
        
        
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }

        if segmentifyObject.lang != nil {
            eventRequest.lang = segmentifyObject.lang
        }
        if segmentifyObject.currency != nil {
            eventRequest.currency = segmentifyObject.currency
        }

        eventRequest.instanceId = nil
        
        eventRequest.externalId = username
        eventRequest.email  = email
        
        setIDAndSendEvent()
    }
    
    //Logout Event
    open func sendUserLogout(segmentifyObject : UserModel) {
        eventRequest.eventName = SegmentifyManager.userOperationEventName
        eventRequest.userOperationStep = SegmentifyManager.logoutStep
        
        let email = segmentifyObject.email
        let username = segmentifyObject.externalId
        
        guard email != nil || username != nil else {
            print("Error - you must fill userId or email before accessing sendUserLogout event")
            return
        }
        
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }

        if segmentifyObject.lang != nil {
            eventRequest.lang = segmentifyObject.lang
        }
        if segmentifyObject.currency != nil {
            eventRequest.currency = segmentifyObject.currency
        }

        eventRequest.instanceId = nil
        
        eventRequest.externalId = username
        eventRequest.email  = email
        
        setIDAndSendEvent()
    }
    
    //User Update Event
    open func sendUserUpdate(segmentifyObject : UserModel) {
        eventRequest.eventName = SegmentifyManager.userOperationEventName
        eventRequest.userOperationStep = SegmentifyManager.updateUserStep
        
        let email = segmentifyObject.email
        let username = segmentifyObject.externalId
        
        guard email != nil || username != nil else {
            print("Error - you must fill username or email before accessing sendUserUpdate event")
            return
        }
        
        UserDefaults.standard.set(email, forKey: "SEGMENTIFY_EMAIL")
        UserDefaults.standard.set(username, forKey: "SEGMENTIFY_USERNAME")
        
        
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }

        if segmentifyObject.lang != nil {
            eventRequest.lang = segmentifyObject.lang
        }
        if segmentifyObject.currency != nil {
            eventRequest.currency = segmentifyObject.currency
        }
        
        eventRequest.instanceId = nil
        
        eventRequest.externalId = username
        eventRequest.email  = email
        eventRequest.fullName = segmentifyObject.fullName
        eventRequest.mobilePhone = segmentifyObject.mobilePhone
        eventRequest.gender = segmentifyObject.gender
        eventRequest.age = segmentifyObject.age
        eventRequest.birthdate = segmentifyObject.birthdate
        eventRequest.memberSince = segmentifyObject.memberSince
        eventRequest.location = segmentifyObject.location
        eventRequest.segments = segmentifyObject.segments
        
        setIDAndSendEvent()
    }

    // Clear Last Search History Event
    open func sendUserClearLastSearchHistory(segmentifyObject : UserModel) {
        eventRequest.eventName = SegmentifyManager.userOperationEventName
        eventRequest.userOperationStep = SegmentifyManager.deleteLastSearchStep

        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }

        if segmentifyObject.lang != nil {
            eventRequest.lang = segmentifyObject.lang
        }
        if segmentifyObject.currency != nil {
            eventRequest.currency = segmentifyObject.currency
        }

        eventRequest.instanceId = nil
        
        eventRequest.lastSearchDeletedKeywords = segmentifyObject.lastSearchDeletedKeywords

        setIDAndSendEvent()
    }
    
    //Change User Event
    @available(*, deprecated)
    open func sendChangeUser(segmentifyObject : UserChangeModel) {
        print("Deprecated - This method is deprecated")
        return
    }
    
    //Checkout Purchase Event
    open func sendPurchase(segmentifyObject : CheckoutModel, callback: @escaping (_ recommendation: [RecommendationModel]) -> Void) {
        eventRequest.eventName = SegmentifyManager.checkoutEventName
        eventRequest.checkoutStep = SegmentifyManager.paymentPurchaseStep
        eventRequest.instanceId = nil
        eventRequest.interactionId = nil
        
        
        
        let totalPrice = segmentifyObject.totalPrice
        guard totalPrice != nil else {
            print("Error - you must fill userId before accessing sendPurchase event")
            return
        }
        let productList = segmentifyObject.productList
        guard productList != nil else {
            print("Error - you must fill productList before accessing sendPurchase event method")
            return
        }
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        if segmentifyObject.orderNo != nil {
            eventRequest.orderNo = segmentifyObject.orderNo
        }
        if segmentifyObject.lang != nil {
            eventRequest.lang = segmentifyObject.lang
        }
        if segmentifyObject.currency != nil {
            eventRequest.currency = segmentifyObject.currency
        }
        if segmentifyObject.params != nil {
            eventRequest.params = segmentifyObject.params
        }
        if segmentifyObject.region != nil {
            eventRequest.region = segmentifyObject.region
        }
        eventRequest.totalPrice = totalPrice
        eventRequest.products  =  productList
        
        // bannerify objects
        if self.clickedBanners.count > 0 {
            var clickedBannerArray = [Any]()
            self.clickedBanners.forEach {
                clickedBanner in
                clickedBannerArray.append(clickedBanner.nsDictionary)
            }
            eventRequest.activeBanners = clickedBannerArray
        }
        
        setIDAndSendEventWithCallback(callback: callback)
    }
    
    //Checkout Payment Event
    open func sendPaymentInformation(segmentifyObject : CheckoutModel, callback: @escaping (_ recommendation: [RecommendationModel]) -> Void) {
        eventRequest.eventName = SegmentifyManager.checkoutEventName
        eventRequest.checkoutStep = SegmentifyManager.paymentInformationStep
        eventRequest.instanceId = nil
        eventRequest.interactionId = nil
        
        
        let totalPrice = segmentifyObject.totalPrice
        guard totalPrice != nil else {
            print("Error - you must fill userId before accessing sendPaymentInformation event method")
            return
        }
        let productList = segmentifyObject.productList
        guard productList != nil else {
            print("Error - you must fill productList before accessing sendPaymentInformation event method")
            return
        }
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        if segmentifyObject.lang != nil {
            eventRequest.lang = segmentifyObject.lang
        }
        if segmentifyObject.currency != nil {
            eventRequest.currency = segmentifyObject.currency
        }
        if segmentifyObject.params != nil {
            eventRequest.params = segmentifyObject.params
        }
        if segmentifyObject.region != nil {
            eventRequest.region = segmentifyObject.region
        }
        eventRequest.totalPrice = totalPrice
        eventRequest.products  =  productList
        
        setIDAndSendEventWithCallback(callback: callback)
    }
    
    //Checkout Customer Information Event
    open func sendCustomerInformation(segmentifyObject : CheckoutModel,callback: @escaping (_ recommendation: [RecommendationModel]) -> Void) {
        eventRequest.eventName = SegmentifyManager.checkoutEventName
        eventRequest.checkoutStep = SegmentifyManager.customerInformationStep
        eventRequest.instanceId = nil
        eventRequest.interactionId = nil
        
        if segmentifyObject.params != nil {
            eventRequest.params = segmentifyObject.params
        }
        if segmentifyObject.lang != nil {
            eventRequest.lang = segmentifyObject.lang
        }
        if segmentifyObject.currency != nil {
            eventRequest.currency = segmentifyObject.currency
        }
        if segmentifyObject.region != nil {
            eventRequest.region = segmentifyObject.region
        }
        
        let totalPrice = segmentifyObject.totalPrice
        guard totalPrice != nil else {
            print("Error - you must fill userId before accessing sendCustomerInformation event method")
            return
        }
        let productList = segmentifyObject.productList
        guard productList != nil else {
            print("Error - you must fill productList before accessing sendCustomerInformation event method")
            return
        }
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }

        eventRequest.totalPrice = totalPrice
        eventRequest.products  =  productList
        
        setIDAndSendEventWithCallback(callback: callback)
    }
    
    //Checkout View Basket Event
    open func sendViewBasket(segmentifyObject : CheckoutModel, callback: @escaping (_ recommendation: [RecommendationModel]) -> Void) {
        eventRequest.eventName = SegmentifyManager.checkoutEventName
        eventRequest.checkoutStep = SegmentifyManager.viewBasketStep
        eventRequest.instanceId = nil
        eventRequest.interactionId = nil
        
        eventRequest.category = nil
        eventRequest.type = nil
        
        if segmentifyObject.params != nil {
            eventRequest.params = segmentifyObject.params
        }
        if segmentifyObject.lang != nil {
            eventRequest.lang = segmentifyObject.lang
        }
        if segmentifyObject.currency != nil {
            eventRequest.currency = segmentifyObject.currency
        }
        if segmentifyObject.region != nil {
            eventRequest.region = segmentifyObject.region
        }

        let totalPrice = segmentifyObject.totalPrice
        guard totalPrice != nil else {
            print("Error - you must fill userId before accessing sendViewBasket event")
            return
        }
        let productList = segmentifyObject.productList
        guard productList != nil else {
            print("Error - you must fill productList before accessing sendViewBasket event method")
            return
        }
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }

        eventRequest.totalPrice = totalPrice
        eventRequest.products  =  productList
        
        setIDAndSendEventWithCallback(callback: callback)
        
    }
    
    //Add or Remove Basket Event
    open func sendAddOrRemoveBasket(segmentifyObject : BasketModel) {
        eventRequest.eventName = SegmentifyManager.basketOperationsEventName
        eventRequest.instanceId = nil
        eventRequest.interactionId = nil
        
        
        let step = segmentifyObject.step
        guard step != nil else {
            print("Error - you must fill step before accessing sendAddOrRemoveBasket event method")
            return
        }
        let productId = segmentifyObject.productId
        guard productId != nil else {
            print("Error - you must fill productId before accessing sendAddOrRemoveBasket event method")
            return
        }
        let quantity = segmentifyObject.quantity
        guard quantity != nil else {
            print("Error - you must fill quantity before accessing sendAddOrRemoveBasket event method")
            return
        }
        eventRequest.basketStep = step
        eventRequest.quantity = quantity
        eventRequest.productID = productId
        
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }

        if segmentifyObject.lang != nil {
            eventRequest.lang = segmentifyObject.lang
        }
        if segmentifyObject.currency != nil {
            eventRequest.currency = segmentifyObject.currency
        }
        if segmentifyObject.region != nil {
            eventRequest.region = segmentifyObject.region
        }
        // bannerify objects
        if self.clickedBanners.count > 0 {
            var clickedBannerArray = [Any]()
            self.clickedBanners.forEach {
                clickedBanner in
                clickedBannerArray.append(clickedBanner.nsDictionary)
            }
            eventRequest.activeBanners = clickedBannerArray
        }
        
        setIDAndSendEvent()
    }
    
    //Product View Event
    @objc open func sendProductView(segmentifyObject : ProductModel, callback: @escaping (_ recommendation: [RecommendationModel]) -> Void) {
        
        eventRequest.eventName = SegmentifyManager.productViewEventName
        eventRequest.instanceId = nil
        eventRequest.interactionId = nil
        
        
        if segmentifyObject.testMode != nil {
            eventRequest.testMode = segmentifyObject.testMode
        }
        if segmentifyObject.lang != nil {
            eventRequest.lang = segmentifyObject.lang
        }
        if segmentifyObject.currency != nil {
            eventRequest.currency = segmentifyObject.currency
        }
        if segmentifyObject.params != nil {
            eventRequest.params = segmentifyObject.params
        }
        if segmentifyObject.region != nil {
            eventRequest.region = segmentifyObject.region
        }
        
        let productId = segmentifyObject.productId
        guard productId != nil else {
            print("Error - you must fill productId before accessing sendProductView event")
            return
        }
        let title = segmentifyObject.name
        guard title != nil else {
            print("Error - you must fill title before accessing sendProductView event method")
            return
        }
        let url = segmentifyObject.url
        guard url != nil else {
            print("Error - you must fill url before accessing sendProductView event method")
            return
        }
        let image = segmentifyObject.image
        guard image != nil else {
            print("Error - you must fill image before accessing sendProductView event method")
            return
        }
        if segmentifyObject.category != nil {
            if segmentifyObject.categories != nil {
                print("Error - you can not both fill category and categpries parameters")
                return
            } else {
                eventRequest.category = segmentifyObject.category
            }
        } else {
            if let categories = segmentifyObject.categories {
                eventRequest.categories = categories
            } else {
                print("Error - you should fill one of category and categpries parameters")
                return
            }
        }
        let price = segmentifyObject.price
        guard price != nil else {
            print("Error - you must fill price before accessing sendProductView event method")
            return
        }
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        eventRequest.productID = segmentifyObject.productId
        eventRequest.title = segmentifyObject.name
        eventRequest.price = segmentifyObject.price
        eventRequest.image = segmentifyObject.image
        eventRequest.url = segmentifyObject.url
        eventRequest.mUrl = segmentifyObject.mUrl
        eventRequest.imageL = segmentifyObject.imageL
        eventRequest.imageM = segmentifyObject.imageM
        eventRequest.imageS = segmentifyObject.imageS
        eventRequest.imageXS = segmentifyObject.imageXS
        eventRequest.imageXL = segmentifyObject.imageXL
        eventRequest.brand = segmentifyObject.brand
        eventRequest.colors = segmentifyObject.colors
        eventRequest.labels = segmentifyObject.labels
        eventRequest.sizes = segmentifyObject.sizes
        eventRequest.gender = segmentifyObject.gender
        eventRequest.oldPrice = segmentifyObject.oldPrice
        eventRequest.noUpdate = segmentifyObject.noUpdate
        eventRequest.inStock = segmentifyObject.inStock
        
        // bannerify objects
        if self.clickedBanners.count > 0 {
            var clickedBannerArray = [Any]()
            self.clickedBanners.forEach {
                clickedBanner in
                clickedBannerArray.append(clickedBanner.nsDictionary)
            }
            eventRequest.activeBanners = clickedBannerArray
        }
        
        setIDAndSendEventWithCallback(callback: callback)
    }

    @objc open func sendSearchPageView(segmentifyObject : SearchPageModel, callback: @escaping (_ searchResponse : SearchModel) -> Void) {
        eventRequest.eventName = SegmentifyManager.searchEventName
        eventRequest.interactionId = nil
        eventRequest.instanceId = nil
        
        eventRequest.query = segmentifyObject.query
        eventRequest.type = "instant"
        // The shared request still holds what the previous search set.
        eventRequest.trigger = nil
        eventRequest.ordering = nil
        eventRequest.filters = nil
        if segmentifyObject.lang != nil {
            eventRequest.lang = segmentifyObject.lang
        }
        if segmentifyObject.currency != nil {
            eventRequest.currency = segmentifyObject.currency
        }
        if segmentifyObject.region != nil {
            eventRequest.region = segmentifyObject.region
        }
        if segmentifyObject.testMode != nil {
            eventRequest.testMode = segmentifyObject.testMode
        }
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        let onFailure = takeErrorHandler()
        if self.eventRequest.sessionID == nil {
            // The shared request is overwritten by the next event; keep this search.
            let snapshot = EventSnapshot(of: eventRequest)
            self.getUserIdAndSessionIdRequest( success: { () -> Void in
                snapshot.applySession(userId: self.eventRequest.userID, sessionId: self.eventRequest.sessionID)
                self.sendSearchEvent(snapshot: snapshot, onFailure: onFailure, callback: { (response: SearchModel) in
                    callback(response)
                })
            }, failure: {
                if let onFailure = onFailure {
                    onFailure(SegmentifyError.noSession())
                } else {
                    callback(SegmentifyManager.failedSearchResult())
                }
            })
        } else {
            self.sendSearchEvent(onFailure: thenClearData(onFailure), callback: { (response: SearchModel) in
                callback(response)
                self.clearData()
            })
        }
    }
    
    open func sendFacetedSearchPageView(segmentifyObject : SearchFacetPageModel, callback: @escaping (_ facetedResponse : FacetedResponseModel) -> Void) {
        eventRequest.eventName = SegmentifyManager.searchEventName
        eventRequest.interactionId = nil
        eventRequest.instanceId = nil
        
        eventRequest.query = segmentifyObject.query
        
        // Assigned unconditionally: the shared request still holds what the
        // previous search set, and a search without filters must not send them.
        eventRequest.trigger = segmentifyObject.trigger
        eventRequest.type = segmentifyObject.type
        eventRequest.ordering = segmentifyObject.ordering
        eventRequest.filters = segmentifyObject.filters?.map { $0.nsDictionary }
        if segmentifyObject.lang != nil {
            eventRequest.lang = segmentifyObject.lang
        }
        if segmentifyObject.currency != nil {
            eventRequest.currency = segmentifyObject.currency
        }
        if segmentifyObject.region != nil {
            eventRequest.region = segmentifyObject.region
        }
        if segmentifyObject.testMode != nil {
            eventRequest.testMode = segmentifyObject.testMode
        }
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        let onFailure = takeErrorHandler()
        if self.eventRequest.sessionID == nil {
            // The shared request is overwritten by the next event; keep this search.
            let snapshot = EventSnapshot(of: eventRequest)
            self.getUserIdAndSessionIdRequest( success: { () -> Void in
                snapshot.applySession(userId: self.eventRequest.userID, sessionId: self.eventRequest.sessionID)
                self.sendSearchFacetedEvent(snapshot: snapshot, onFailure: onFailure, callback: { (response: FacetedResponseModel) in
                    callback(response)
                })
            }, failure: {
                if let onFailure = onFailure {
                    onFailure(SegmentifyError.noSession())
                } else {
                    callback(self.makeEmptyFacetedResponse())
                }
            })
        } else {
            self.sendSearchFacetedEvent(onFailure: thenClearData(onFailure), callback: { (response: FacetedResponseModel) in
                callback(response)
                self.clearData()
            })
        }
    }

    //Page View Event
    @objc open func sendPageView(segmentifyObject : PageModel, callback: @escaping (_ recommendation: [RecommendationModel]) -> Void) {

        eventRequest.eventName = SegmentifyManager.pageViewEventName
        eventRequest.interactionId = nil
        eventRequest.instanceId = nil
        
        if segmentifyObject.lang != nil {
            eventRequest.lang = segmentifyObject.lang
        }
        if segmentifyObject.currency != nil {
            eventRequest.currency = segmentifyObject.currency
        }
        if segmentifyObject.testMode != nil {
            eventRequest.testMode = segmentifyObject.testMode
        }
        if segmentifyObject.params != nil {
            eventRequest.params = segmentifyObject.params
        }
        if segmentifyObject.region != nil {
            eventRequest.region = segmentifyObject.region
        }
        let category = segmentifyObject.category
        guard category != nil else {
            print("Error - you must fill category before accessing sendPageView event method")
            return
        }
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        eventRequest.category = segmentifyObject.category

        if (segmentifyObject.subCategory != nil) {
            eventRequest.subCategory = segmentifyObject.subCategory
        }
        if (segmentifyObject.recommendIds != nil) {
            eventRequest.recommendIds = segmentifyObject.recommendIds
        }
        setIDAndSendEventWithCallback(callback: callback)
    }
    
    //Custom Event
    @objc open func sendCustomEvent(segmentifyObject : CustomEventModel, callback: @escaping (_ recommendation: [RecommendationModel]) -> Void) {
        eventRequest.eventName = SegmentifyManager.customEventName
        let type = segmentifyObject.type
        guard type != nil else {
            print("Error - you must fill type before accessing sendCustomEvent event method")
            return
        }
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        
        eventRequest.interactionId = nil
        eventRequest.instanceId = nil
        eventRequest.type = segmentifyObject.type
        if segmentifyObject.lang != nil {
            eventRequest.lang = segmentifyObject.lang
        }
        if segmentifyObject.currency != nil {
            eventRequest.currency = segmentifyObject.currency
        }
        if segmentifyObject.testMode != nil {
            eventRequest.testMode = segmentifyObject.testMode
        }
        if segmentifyObject.params != nil {
            eventRequest.params = segmentifyObject.params
        }
        if segmentifyObject.region != nil {
            eventRequest.region = segmentifyObject.region
        }
        
        setIDAndSendEventWithCallback(callback: callback)
    }
    
    func sendWidgetView(segmentifyObject: InteractionModel) {
        eventRequest.eventName = SegmentifyManager.interactionEventName
        eventRequest.userOperationStep = SegmentifyManager.widgetViewStep
    }
    
    func sendClick(segmentifyObject : InteractionModel) {
        eventRequest.eventName = SegmentifyManager.interactionEventName
        eventRequest.userOperationStep = SegmentifyManager.clickStep
    }
    
    //Alternative Events
    //Register Event
    open func sendUserRegister(username : String?, fullName : String?, email : String?, mobilePhone : String?, gender : String?, age : String?, birthdate : String?) {
        eventRequest.eventName = SegmentifyManager.userOperationEventName
        eventRequest.userOperationStep = SegmentifyManager.updateUserStep
        
        eventRequest.interactionId = nil
        eventRequest.instanceId = nil
        if let username = username {
            eventRequest.externalId = username
        }
        if let fullName = fullName {
            eventRequest.fullName = fullName
        }
        if let email = email {
            eventRequest.email = email
        }
        if let mobilePhone = mobilePhone {
            eventRequest.mobilePhone = mobilePhone
        }
        if let gender = gender {
            eventRequest.gender = gender
        }
        if let age = age {
            eventRequest.age = age
        }
        if let birthdate = birthdate {
            eventRequest.birthdate = birthdate
        }
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        }else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        setIDAndSendEvent()
    }
    
    //Login Event
    open func sendUserLogin(username: String?, email: String?) {
        eventRequest.eventName = SegmentifyManager.userOperationEventName
        eventRequest.userOperationStep = SegmentifyManager.signInStep
        
        eventRequest.interactionId = nil
        eventRequest.instanceId = nil
        if let username = username {
            eventRequest.externalId = username
        }
        if let email = email {
            eventRequest.email = email
        }
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        }else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        setIDAndSendEvent()
    }
    
    //Logout Event
    open func sendUserLogout(username: String?, email: String?) {
        eventRequest.eventName = SegmentifyManager.userOperationEventName
        eventRequest.userOperationStep = SegmentifyManager.signInStep
        
        eventRequest.interactionId = nil
        eventRequest.instanceId = nil
        
        if let username = username {
            eventRequest.externalId = username
        }
        if let email = email {
            eventRequest.email = email
        }
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        }else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        setIDAndSendEvent()
    }
    
    //User Update Event
    open func sendUserUpdate(username : String?, fullName : String?, email : String?, mobilePhone : String?, gender : String?, age : String?, birthdate : String?, isRegistered : AnyObject?, isLogin : AnyObject?) {
        eventRequest.eventName = SegmentifyManager.userOperationEventName
        eventRequest.userOperationStep = SegmentifyManager.updateUserStep
        eventRequest.externalId = username
        eventRequest.interactionId = nil
        eventRequest.instanceId = nil
        
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        if let fullName = fullName {
            eventRequest.fullName = fullName
        }
        if let username = username {
            eventRequest.externalId = username
        }
        if let email = email {
            eventRequest.email = email
        }
        if let mobilePhone = mobilePhone {
            eventRequest.mobilePhone = mobilePhone
        }
        if let gender = gender {
            eventRequest.gender = gender
        }
        if let age = age {
            eventRequest.age = age
        }
        if let birthdate = birthdate {
            eventRequest.birthdate = birthdate
        }
        if let isRegistered = isRegistered {
            eventRequest.isRegistered = isRegistered as? Bool
        }
        if let isLogin = isLogin {
            eventRequest.isLogin = isLogin as? Bool
        }
        setIDAndSendEvent()
    }

    //Checkout Purchase Event
    open func sendPurchase(totalPrice : NSNumber, productList:[Any], orderNo : String?,lang :String?,  params :[String:AnyObject]?, callback: @escaping (_ recommendation: [RecommendationModel]) -> Void) {
        eventRequest.eventName = SegmentifyManager.checkoutEventName
        eventRequest.totalPrice = totalPrice
        eventRequest.products = productList
        eventRequest.checkoutStep = SegmentifyManager.paymentPurchaseStep
        eventRequest.interactionId = nil
        eventRequest.instanceId = nil
        
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        if let orderNo = orderNo {
            eventRequest.orderNo = orderNo
        }
        
        if let lang = lang {
            eventRequest.lang = lang
        }
        
        if let params = params {
            eventRequest.params = params
        }
        
        setIDAndSendEventWithCallback(callback: callback)
    }
    
    //Checkout Payment Event
    open func sendPaymentInformation(totalPrice : NSNumber, productList : [Any],lang :String?,  params :[String:AnyObject]?, callback: @escaping (_ recommendation: [RecommendationModel]) -> Void) {
        eventRequest.eventName = SegmentifyManager.checkoutEventName
        eventRequest.totalPrice = totalPrice
        eventRequest.checkoutStep = SegmentifyManager.paymentInformationStep
        eventRequest.interactionId = nil
        eventRequest.instanceId = nil
        
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }

        if let lang = lang {
            eventRequest.lang = lang
        }

        if let params = params {
            eventRequest.params = params
        }
        
        setIDAndSendEventWithCallback(callback: callback)
    }
    
    //Checkout Customer Information Event
    open func sendCustomerInformation(totalPrice : NSNumber, productList : [Any],lang :String?,  params :[String:AnyObject]?, callback: @escaping (_ recommendation: [RecommendationModel]) -> Void) {
        eventRequest.eventName = SegmentifyManager.checkoutEventName
        eventRequest.totalPrice = totalPrice
        eventRequest.products = productList
        eventRequest.checkoutStep = SegmentifyManager.customerInformationStep
        eventRequest.interactionId = nil
        eventRequest.instanceId = nil
        
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        
        if let lang = lang {
            eventRequest.lang = lang
        }

        if let params = params {
            eventRequest.params = params
        }
        
        setIDAndSendEventWithCallback(callback: callback)
    }
    
    //Checkout View Basket Event
    open func sendViewBasket(totalPrice : NSNumber, productList : [Any], currency : String?,lang :String?, params :[String:AnyObject]?, callback: @escaping (_ recommendation: [RecommendationModel]) -> Void) {
        eventRequest.eventName = SegmentifyManager.checkoutEventName
        eventRequest.totalPrice = totalPrice
        eventRequest.products = productList
        eventRequest.checkoutStep = SegmentifyManager.viewBasketStep
        eventRequest.interactionId = nil
        eventRequest.instanceId = nil
        
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        }
        if let currency = currency {
            eventRequest.currency = currency
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        
        if let lang = lang {
            eventRequest.lang = lang
        }

        if let params = params {
            eventRequest.params = params
        }
        
        setIDAndSendEventWithCallback(callback: callback)
    }
    
    //Add or Remove Basket Event
    open func sendAddOrRemoveBasket(basketStep : String, productID : String, quantity : NSNumber,price : NSNumber?) {
        eventRequest.eventName = SegmentifyManager.basketOperationsEventName
        eventRequest.basketStep = basketStep
        eventRequest.productID = productID
        eventRequest.quantity = quantity
        eventRequest.interactionId = nil
        eventRequest.instanceId = nil
        
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        if let price = price {
            eventRequest.price = price
        }
        setIDAndSendEvent()
    }
    
    //Product View Event
    @objc open func sendProductView(productID : String, title : String, category : [String], price : NSNumber, brand : String?, inStock : AnyObject?, url: String, image : String,imageXS: String?, imageS: String?, imageM: String?, imageL: String?, imageXL: String?, gender:String?, colors:[String]?, sizes:[String]?, labels:[String]?,noUpdate:AnyObject? ,lang :String?,  params :[String:AnyObject]?, region :String?,  callback: @escaping (_ recommendation: [RecommendationModel]) -> Void ) {
        
        eventRequest.eventName = SegmentifyManager.productViewEventName
        eventRequest.productID = productID
        eventRequest.title = title
        eventRequest.price = price
        eventRequest.categories = category
        eventRequest.image = image
        eventRequest.url = url
        eventRequest.interactionId = nil
        eventRequest.instanceId = nil
        
        
        if let lang = lang {
            eventRequest.lang = lang
        }
        if let region = region {
            eventRequest.region = region
        }
        if let params = params {
            eventRequest.params = params
        }
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        if let brand = brand {
            eventRequest.brand = brand
        }
        if let inStock = inStock {
            eventRequest.inStock = inStock as? Bool
        }
        if let imageXS = imageXS {
            eventRequest.imageXS = imageXS
        }
        if let imageS = imageS {
            eventRequest.imageS = imageS
        }
        if let imageM = imageM {
            eventRequest.imageM = imageM
        }
        if let imageL = imageL {
            eventRequest.imageL = imageL
        }
        if let imageXL = imageXL {
            eventRequest.imageXL = imageXL
        }
        if let gender = gender {
            eventRequest.gender = gender
        }
        if let colors = colors {
            eventRequest.colors = colors
        }
        if let sizes = sizes {
            eventRequest.sizes = sizes
        }
        if let labels = labels {
            eventRequest.labels = labels
        }
        if let noUpdate = noUpdate {
            eventRequest.noUpdate = noUpdate as? Bool
        }
        setIDAndSendEventWithCallback(callback: callback)
    }
    
    //Page View Event
    @objc open func sendPageView(category : String, subCategory : String?,recommendIds: [String]?, lang: String?, params :[String:AnyObject]? , callback: @escaping (_ recommendation: [RecommendationModel]) -> Void) {
        eventRequest.eventName = SegmentifyManager.pageViewEventName
        eventRequest.category = category
        eventRequest.interactionId = nil
        eventRequest.instanceId = nil
        
        
        if let lang = lang {
            eventRequest.lang = lang
        }
        
        if let recommendIds = recommendIds {
            eventRequest.recommendIds = recommendIds
        }
        
        
        if let params = params {
            eventRequest.params = params
        }

        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        
        if let subCategory = subCategory {
            eventRequest.subCategory = subCategory
        }
        if let recommendIds = recommendIds {
            eventRequest.recommendIds = recommendIds
        }
        setIDAndSendEventWithCallback(callback: callback)
    }
    
    open func sendCustomEvent(type : String, params :[String:AnyObject]?, lang : String?, callback: @escaping (_ recommendation: [RecommendationModel]) -> Void) {
        eventRequest.eventName = SegmentifyManager.customEventName
        eventRequest.type = type
        
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        }else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        
        if let lang = lang {
            eventRequest.lang = lang
        }
        
        if let params = params {
            eventRequest.params = params
        }

        eventRequest.interactionId = nil
        eventRequest.instanceId = nil
        
        setIDAndSendEventWithCallback(callback: callback)
    }
    
    open func sendImpression(instanceId : String, interactionId : String) {
        eventRequest.eventName = SegmentifyManager.interactionEventName
        eventRequest.type = SegmentifyManager.impressionStep
        eventRequest.instanceId = instanceId
        eventRequest.interactionId = interactionId
        
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        }else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        
        setIDAndSendEvent()
    }
    
    open func sendWidgetView(instanceId : String, interactionId : String) {
        eventRequest.eventName = SegmentifyManager.interactionEventName
        eventRequest.type = SegmentifyManager.widgetViewStep
        eventRequest.instanceId = instanceId
        eventRequest.interactionId = interactionId
        
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        }else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        
        setIDAndSendEvent()
    }

    open func sendSearchClickView(instanceId : String, interactionId : String) {
        eventRequest.eventName = SegmentifyManager.interactionEventName
        eventRequest.type = SegmentifyManager.searchStep
        eventRequest.instanceId = instanceId
        eventRequest.interactionId = interactionId

        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        
        setIDAndSendEvent()
    }
    
    open func sendClickView(instanceId : String, interactionId : String) {
        eventRequest.eventName = SegmentifyManager.interactionEventName
        eventRequest.type = SegmentifyManager.clickStep
        eventRequest.instanceId = instanceId
        eventRequest.interactionId = interactionId
        
        if instanceId.starts(with: "fcs_"){
            eventRequest.interactionId = interactionId + "|product"
        }

        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        
        setIDAndSendEvent()
    }
    
    /* bannerify events */
    
    //Banner Impression Event
    open func sendBannerImpressionEvent(segmentifyObject : BannerOperationsModel) {
        
        if segmentifyObject.type == nil {
            segmentifyObject.type = SegmentifyManager.bannerImpressionStep
        }
        
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        
        eventRequest.eventName = SegmentifyManager.bannerOperationsEventName
        eventRequest.title = segmentifyObject.title
        eventRequest.group = segmentifyObject.group
        eventRequest.order = segmentifyObject.order
        eventRequest.productID = segmentifyObject.productId
        eventRequest.categories = segmentifyObject.category
        eventRequest.brand = segmentifyObject.brand
        eventRequest.label = segmentifyObject.label
        eventRequest.type = segmentifyObject.type

        setIDAndSendEvent()
    }
    
    //Banner Click Event
    open func sendBannerClickEvent(segmentifyObject : BannerOperationsModel) {
        
        if segmentifyObject.type == nil {
            segmentifyObject.type = SegmentifyManager.bannerClickStep
        }
        
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        
        self.addClickedBanner(banner: segmentifyObject)
        eventRequest.eventName = SegmentifyManager.bannerOperationsEventName
        eventRequest.title = segmentifyObject.title
        eventRequest.group = segmentifyObject.group
        eventRequest.order = segmentifyObject.order
        eventRequest.productID = segmentifyObject.productId
        eventRequest.categories = segmentifyObject.category
        eventRequest.brand = segmentifyObject.brand
        eventRequest.label = segmentifyObject.label
        eventRequest.type = segmentifyObject.type
        
        setIDAndSendEvent()
    }
    
    //Banner Update Event
    open func sendBannerUpdateEvent(segmentifyObject : BannerOperationsModel) {
        
        if segmentifyObject.type == nil {
            segmentifyObject.type = SegmentifyManager.bannerUpdateStep
        }
        
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        
        eventRequest.eventName = SegmentifyManager.bannerOperationsEventName

        setIDAndSendEvent()
    }
    
    //Banner GroupView Event
    open func sendBannerGroupViewEvent(segmentifyObject : BannerGroupViewModel) {
        
        var bannerArray = [Any]()
        segmentifyObject.banners?.forEach {
            banner in
            bannerArray.append(banner.nsDictionary)
        }
        
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        
        eventRequest.group = segmentifyObject.group
        eventRequest.banners = bannerArray
        eventRequest.eventName = SegmentifyManager.internalBannerGroupEventName
        
        setIDAndSendEvent()
    }
    
    //Banner InternalBannerGroup Event
    open func sendInternalBannerGroupEvent(segmentifyObject : BannerGroupViewModel) {
        
        var bannerArray = [Any]()
        segmentifyObject.banners?.forEach {
            banner in
            bannerArray.append(banner.nsDictionary)
        }
        
        if UserDefaults.standard.object(forKey: "UserSentUserId") != nil {
            eventRequest.userID = UserDefaults.standard.object(forKey: "UserSentUserId") as? String
        } else {
            if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
                self.eventRequest.userID = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
            }
        }
        
        eventRequest.group = segmentifyObject.group
        eventRequest.banners = bannerArray
        eventRequest.eventName = SegmentifyManager.internalBannerGroupEventName
        
        setIDAndSendEvent()
    }
    
    func addClickedBanner(banner: BannerOperationsModel) {
        
        let results = self.clickedBanners.filter {$0.group == banner.group && $0.title == banner.title && $0.order == banner.order }
        let exists = results.isEmpty == false
        if(exists){
            return
        }
        
        if (self.clickedBanners.count > 20) {
            self.clickedBanners.removeFirst()
        }
        
        let cbo = ClickedBannerObject()
        cbo.group = banner.group
        cbo.order = banner.order
        cbo.title = banner.title
        
        self.clickedBanners.insert(cbo, at: 0)
    }
    
    func setAdvertisingIdentifier(adIdentifier: String?) {
        if let adIdentifier = adIdentifier {
            eventRequest.advertisingIdentifier = adIdentifier
        }
    }
    
    func setAppVersion(appVersion: String?) {
        if let appVersion = appVersion {
            eventRequest.appVersion = appVersion
        }
    }
    
    func addParams(key: String, value: AnyObject?) {
        if let value = value {
            eventRequest.extra[key] = value
        }
    }
    
    func addCustomParameter(key: String?, value: AnyObject?) {
        if (key != nil && value != nil) {
            eventRequest.extra[key!] = value
        }
    }
    
    func removeUserParameters() {
        eventRequest.extra.removeAll()
    }

    func initSessionId(sessionId :String!){
        let nw  =  NSDate().timeIntervalSince1970
        _ = round(NSDate().timeIntervalSince1970)
        let nowDate = Date(timeIntervalSince1970: nw)
        
        let y=nowDate.addingTimeInterval(TimeInterval(SegmentifyManager._sessionKeepSecond))
        let newDate = y
        let addedInterval = round(newDate.timeIntervalSince1970)
        _ = Date(timeIntervalSince1970: TimeInterval(addedInterval))
        UserDefaults.standard.set(sessionId ,forKey: "SEGMENTIFY_SESSION_ID")
        UserDefaults.standard.set(addedInterval,forKey: "SEGMENTIFY_SESSION_ID_TIMESTAMP")
    }
    
    // MARK: Session bootstrap

    private typealias SessionWaiter = (success: () -> Void, failure: (() -> Void)?)

    /// Fetches the user id and session id. Callers that arrive while a request
    /// is running wait for it instead of starting their own. Transport errors
    /// and 5xx answers are retried after `sessionRetryDelays`; every caller
    /// then hears back exactly once, on the main queue.
    private func getUserIdAndSessionIdRequest(success : @escaping () -> Void, failure: (() -> Void)? = nil) {
        sessionLock.lock()
        sessionWaiters.append((success: success, failure: failure))
        let alreadyRequesting = isRequestingSession
        isRequestingSession = true
        sessionLock.unlock()

        if !alreadyRequesting {
            performSessionRequest(attempt: 1)
        }
    }

    private func performSessionRequest(attempt: Int) {
        let keyCount = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil ? 1 : 2
        guard let dataCenterUrl = SegmentifyManager.setup.dataCenterUrl,
              let requestURL = URL(string: dataCenterUrl + "/get/key?count=\(keyCount)") else {
            finishSessionRequest(succeeded: false)
            return
        }

        var keyRequest = URLRequest(url: requestURL)
        SegmentifyUserAgent.apply(to: &keyRequest)
        let task = SegmentifyConnectionManager.urlSession.dataTask(with: keyRequest) {
            (data, response, error) -> Void in

            guard let httpResponse = response as? HTTPURLResponse else {
                self.retrySessionRequestOrFail(after: attempt)
                return
            }
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode >= 500 || httpResponse.statusCode == 429 || httpResponse.statusCode == 408 {
                    self.retrySessionRequestOrFail(after: attempt)
                } else {
                    self.finishSessionRequest(succeeded: false)
                }
                return
            }
            guard let data = data,
                  let jsonArray = (try? JSONSerialization.jsonObject(with: data, options: [])) as? NSArray,
                  jsonArray.count > 0 else {
                self.finishSessionRequest(succeeded: false)
                return
            }

            self.storeSessionKeys(jsonArray)
            self.finishSessionRequest(succeeded: true)
        }
        task.resume()
    }

    private func retrySessionRequestOrFail(after attempt: Int) {
        let delays = SegmentifyManager.sessionRetryDelays
        guard attempt <= delays.count else {
            finishSessionRequest(succeeded: false)
            return
        }
        // Default QoS: utility work can be held back for seconds on a busy device.
        DispatchQueue.global().asyncAfter(deadline: .now() + delays[attempt - 1]) {
            self.performSessionRequest(attempt: attempt + 1)
        }
    }

    private func finishSessionRequest(succeeded: Bool) {
        sessionLock.lock()
        let waiters = sessionWaiters
        sessionWaiters.removeAll()
        isRequestingSession = false
        sessionLock.unlock()

        DispatchQueue.main.async {
            if succeeded {
                self.sendWaitingEvents()
            }
            for waiter in waiters {
                if succeeded {
                    waiter.success()
                } else {
                    waiter.failure?()
                }
            }
        }
    }

    // MARK: Error callback

    /// Runs `send`, one of the `callback:`-only methods, so that its failure
    /// goes to `onError`.
    func reportingErrors(to onError: @escaping (SegmentifyError) -> Void, _ send: () -> Void) {
        pendingErrorHandler = onError
        send()

        // Still there: the method returned before it got to sending.
        if pendingErrorHandler != nil {
            pendingErrorHandler = nil
            let error = SegmentifyError(message: "The event was not sent: a required field is missing or not valid, see the log")
            DispatchQueue.main.async { onError(error) }
        }
    }

    /// `onFailure` followed by the clean-up a call with a session does after
    /// its answer.
    private func thenClearData(_ onFailure: ((SegmentifyError) -> Void)?) -> ((SegmentifyError) -> Void)? {
        guard let onFailure = onFailure else {
            return nil
        }
        return { (error: SegmentifyError) in
            onFailure(error)
            self.clearData()
        }
    }

    /// The error handler of the call being made, when it was made through an
    /// `onError` variant. Taking it means the call got as far as sending.
    func takeErrorHandler() -> ((SegmentifyError) -> Void)? {
        defer { pendingErrorHandler = nil }
        return pendingErrorHandler
    }

    // MARK: Events waiting for a session

    /// Keeps the event until a session exists. Every successful session request
    /// sends all waiting events, oldest first.
    private func sendWhenSessionIsReady(
        _ snapshot: EventSnapshot,
        callback: ((_ recommendation: [RecommendationModel]) -> Void)?,
        onFailure: ((SegmentifyError) -> Void)? = nil
    ) {
        if !snapshot.isConfigured {
            logWaitingEvent("refused, SegmentifyManager.config was not called", snapshot)
            DispatchQueue.main.async {
                if let onFailure = onFailure {
                    onFailure(SegmentifyError.from(SegmentifyNetworkError.notConfigured))
                } else {
                    callback?([])
                }
            }
            return
        }
        sessionLock.lock()
        waitingEvents.append((snapshot: snapshot, callback: callback, onFailure: onFailure))
        var dropped: WaitingEvent?
        if waitingEvents.count > SegmentifyManager.maxWaitingEvents {
            dropped = waitingEvents.removeFirst()
        }
        sessionLock.unlock()

        if let dropped = dropped {
            logWaitingEvent("dropped, too many events are waiting for a session", dropped.snapshot)
            if let onFailure = dropped.onFailure {
                DispatchQueue.main.async { onFailure(SegmentifyError(message: "The event was dropped: too many events are waiting for a session")) }
            } else if let droppedCallback = dropped.callback {
                DispatchQueue.main.async { droppedCallback([]) }
            }
        }

        getUserIdAndSessionIdRequest(success: {}, failure: { self.sessionFailedForWaitingEvents() })
    }

    private func sendWaitingEvents() {
        sessionLock.lock()
        let events = waitingEvents
        waitingEvents.removeAll()
        sessionLock.unlock()

        for event in events {
            event.snapshot.applySession(userId: eventRequest.userID, sessionId: eventRequest.sessionID)
            let callback = event.callback
            sendEvent(snapshot: event.snapshot, onFailure: event.onFailure, callback: { (response: [RecommendationModel]) in
                callback?(response)
            })
        }
    }

    /// No session could be obtained. Events with a callback answer it with an
    /// empty result and are given up; events without one have nobody to tell,
    /// so they stay and go out with the next session (next event or foreground).
    private func sessionFailedForWaitingEvents() {
        sessionLock.lock()
        let answered = waitingEvents.filter { $0.callback != nil }
        waitingEvents = waitingEvents.filter { $0.callback == nil }
        let kept = waitingEvents
        sessionLock.unlock()

        for event in answered {
            if let onFailure = event.onFailure {
                onFailure(SegmentifyError.noSession())
            } else {
                event.callback?([])
            }
        }
        for event in kept {
            logWaitingEvent("kept until a session is available", event.snapshot)
        }
    }

    private func logWaitingEvent(_ message: String, _ snapshot: EventSnapshot) {
        if SegmentifyManager.logStatus {
            print("Segmentify: event \(snapshot.eventName ?? "unknown") \(message)")
        }
    }

    /// Stores the keys returned by `/get/key`. Logic unchanged; see SFY-28779.
    private func storeSessionKeys(_ jsonArray: NSArray) {
        if jsonArray.count > 1 {
            self.eventRequest.userID = jsonArray[0] as? String
            self.eventRequest.sessionID = jsonArray[1] as? String
            self.initSessionId(sessionId: jsonArray[1] as? String)
            UserDefaults.standard.set(self.eventRequest.userID, forKey: "SEGMENTIFY_USER_ID")
        } else {

            let nw  =  NSDate().timeIntervalSince1970
            let nowInterval = round(NSDate().timeIntervalSince1970)
            _ = Date(timeIntervalSince1970: nw)

            if UserDefaults.standard.object(forKey: "SEGMENTIFY_SESSION_ID_TIMESTAMP") != nil{
                let lastStamp = nowInterval + round(Double(SegmentifyManager._sessionKeepSecond))
                UserDefaults.standard.set(lastStamp,forKey: "SEGMENTIFY_SESSION_ID_TIMESTAMP")
            } else{
                // A single key was requested, so the only element is the session id.
                self.initSessionId(sessionId: jsonArray[0] as? String)
            }

            let getLastStamp = UserDefaults.standard.object(forKey: "SEGMENTIFY_SESSION_ID_TIMESTAMP")
            let getLastStampToDouble = getLastStamp  as! Double
            if (nowInterval <= getLastStampToDouble) {
                print(nowInterval)
                print(getLastStampToDouble)

                let sessionId = UserDefaults.standard.object(forKey: "SEGMENTIFY_SESSION_ID") as? String
                self.eventRequest.sessionID = sessionId
            } else {
                let lastStamp = nowInterval + round(Double(SegmentifyManager._sessionKeepSecond))
                UserDefaults.standard.set(lastStamp, forKey: "SEGMENTIFY_SESSION_ID_TIMESTAMP")
                UserDefaults.standard.set(jsonArray[0] as? String, forKey: "SEGMENTIFY_SESSION_ID")
                self.eventRequest.sessionID = jsonArray[0] as? String
            }
        }
    }

    /// Back to a process that never configured the SDK.
    static func testingUnconfigure() {
        segmentifySharedInstance = nil
        setup.apiKey = nil
        setup.dataCenterUrl = nil
        setup.subDomain = nil
        setup.dataCenterUrlPush = nil
    }

    func testingPrepareNetworkSession(
        userId: String = "test-user",
        sessionId: String = "test-session"
    ) {
        eventRequest.userID = userId
        eventRequest.sessionID = sessionId
    }

    /// True when no key request is running and nobody waits for one.
    var testingIsSessionRequestIdle: Bool {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        return !isRequestingSession && sessionWaiters.isEmpty
    }

    func testingClearNetworkSession() {
        eventRequest.sessionID = nil
        eventRequest.userTraitsProperties = nil
        sessionLock.lock()
        waitingEvents.removeAll()
        sessionLock.unlock()
    }

    func testingConfigureFacetedSearch(
        query: String,
        type: String? = nil,
        lang: String? = "EN"
    ) {
        eventRequest.eventName = SegmentifyManager.searchEventName
        eventRequest.interactionId = nil
        eventRequest.instanceId = nil
        
        eventRequest.userTraitsProperties = nil
        eventRequest.query = query
        eventRequest.type = type
        eventRequest.lang = lang
    }

    func testingCurrentRequestDictionary() -> Dictionary<AnyHashable, Any> {
        eventRequest.toDictionary()
    }

    func testingResetSearchResponses() {
        searchResponse = SearchModel()
        facetedResponse = Self.createEmptyFacetedResponse()
    }
}

// MARK: - CDP Event Pipeline Support

extension SegmentifyManager: CdpSessionResolving, CdpRequestBuilding {
    /// Resolves the current user / session for a CDP event. Mirrors the session
    /// bootstrapping in `setIDAndSendEvent`, but returns the identifiers instead
    /// of routing CDP payloads through the shared request state.
    func resolveCdpSession(completion: @escaping (String?, String?) -> Void) {
        if let sentUserId = UserDefaults.standard.object(forKey: "UserSentUserId") as? String {
            eventRequest.userID = sentUserId
        }

        if eventRequest.sessionID == nil {
            getUserIdAndSessionIdRequest(success: {
                completion(self.eventRequest.userID, self.eventRequest.sessionID)
            }, failure: {
                // No session could be obtained; the caller decides what that means.
                completion(self.eventRequest.userID, nil)
            })
        } else {
            completion(eventRequest.userID, eventRequest.sessionID)
        }
    }

    /// Builds a fresh request carrying only connection-level configuration, so a
    /// CDP event never inherits event-specific state from a previous send.
    func makeCdpRequest() -> SegmentifyRegisterRequest {
        let request = SegmentifyRegisterRequest()
        request.apiKey = eventRequest.apiKey
        request.dataCenterUrl = eventRequest.dataCenterUrl
        request.subdomain = eventRequest.subdomain
        request.sdkVersion = eventRequest.sdkVersion
        request.token = eventRequest.token
        request.testMode = eventRequest.testMode
        request.extra = eventRequest.extra
        return request
    }
}

@available(*, deprecated, message: "Not part of the Segmentify SDK; it will be removed in a future release.")
public func daysBetween(start: Date, end: Date) -> Int {
    return Calendar.current.dateComponents([.day], from: start, to: end).day!
}

/// A closure, so that it can be kept in a thread's dictionary.
private final class ErrorHandlerBox {
    let handler: (SegmentifyError) -> Void

    init(_ handler: @escaping (SegmentifyError) -> Void) {
        self.handler = handler
    }
}
