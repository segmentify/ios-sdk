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
    static let pushStep = "push"
    static let pushClickStep = "push-click"
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
    private var eventRequest = SegmentifyRegisterRequest()
    private static let setup = ConfigModel()
    // log status variable. Default: true
    static var logStatus: Bool = true
    static var authToken: String? {
        return SegmentifyManager.setup.authToken
    }
    static var _sessionKeepSecond: Int = 86400
    // set log status
    public class func logStatus(isVisible: Bool) -> Bool{
        logStatus = isVisible
        return isVisible
    }
    
    public class func setSessionKeepSecond(sessionKeepSecond: Int) -> Int{
        _sessionKeepSecond = sessionKeepSecond
        return sessionKeepSecond
    }

    public class func setConfig(apiKey: String? = nil, dataCenterUrl : String, subDomain : String, authToken: String? = nil) {
        SegmentifyManager.setup.apiKey = apiKey
        SegmentifyManager.setup.authToken = authToken
        SegmentifyManager.setup.dataCenterUrl = dataCenterUrl
        SegmentifyManager.setup.subDomain = subDomain
        segmentifySharedInstance = SegmentifyManager.init()
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
    
    public class func config(appkey: String? = nil, dataCenterUrl: String, subDomain: String, authToken: String? = nil) {
        SegmentifyManager.setup.apiKey = appkey
        SegmentifyManager.setup.authToken = authToken
        SegmentifyManager.setup.dataCenterUrl = dataCenterUrl
        SegmentifyManager.setup.subDomain = subDomain
        _ = sharedManager()
    }
    
    var debugMode = false {
        didSet {
            SegmentifyConnectionManager.sharedInstance.debugMode = debugMode
        }
    }
    
    override init() {
        super.init()
        self.eventRequest = SegmentifyRegisterRequest()
        
        let appkey = SegmentifyManager.setup.apiKey
        let authToken = SegmentifyManager.setup.authToken
        guard appkey != nil || authToken != nil else {
            print("Error - you must fill either appKey or authToken before accessing SegmentifyManager.shared")
            return
        }
        if let appkey = appkey {
            eventRequest.apiKey = appkey
        }
        
        let subDomain = SegmentifyManager.setup.subDomain
        guard subDomain != nil else {
            print("Error - you must fill subdomain before accessing SegmentifyManager.shared")
            return
        }
        eventRequest.subdomain = subDomain!
        
        let dataCenterUrl = SegmentifyManager.setup.dataCenterUrl
        guard dataCenterUrl != nil else {
            print("Error - you must fill dataCenterUrl before accessing SegmentifyManager.shared")
            return
        }
        eventRequest.dataCenterUrl = dataCenterUrl!
        
        eventRequest.sdkVersion = SegmentifyManager.sdkVersion
        eventRequest.token = SegmentifyTools.retrieveUserDefaults(userKey: SegmentifyManager.tokenKey) as? String
        
        if let lastRegister = SegmentifyTools.retrieveUserDefaults(userKey: SegmentifyManager.registerKey) {
            let lastRequest = SegmentifyRegisterRequest.init(withJsonString: lastRegister as! String)
            eventRequest.extra = (lastRequest?.extra)!
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
            self.getUserIdAndSessionIdRequest( success: { () -> Void in
                self.sendEvent(callback: { (response: [RecommendationModel]) in
                })
            })
        } else {
            self.sendEvent(callback: { (response: [RecommendationModel]) in
            })
        }
    }
    
    func setIDAndSendEventWithCallback(callback: @escaping (_ recommendation: [RecommendationModel]) -> Void) {
        if self.eventRequest.sessionID == nil {
            self.getUserIdAndSessionIdRequest( success: { () -> Void in
                self.sendEvent(callback: { (response: [RecommendationModel]) in
                    callback(response)
                })
            })
        } else {
            self.sendEvent(callback: { (response: [RecommendationModel]) in
                callback(response)
                self.clearData()
                
            })
        }
    }
    
    func sendSearchEvent(callback: @escaping (_ recommendation: SearchModel) -> Void) {
        SegmentifyConnectionManager.sharedInstance.request(requestModel: eventRequest, success: {(response: [String:AnyObject]) in
            
            guard let searches = response["search"] as? [[Dictionary<AnyHashable,Any>]] else {
                print("error : \(response["statusCode"]! as Any)")
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
            let errorRecModel = SearchModel()
            errorRecModel.errorString = "error"
            callback(self.searchResponse)
        })
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

    func sendSearchFacetedEvent(callback: @escaping (_ recommendation: FacetedResponseModel) -> Void) {
        SegmentifyConnectionManager.sharedInstance.request(requestModel: eventRequest, success: {(response: [String:AnyObject]) in
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
            self.deliverFacetedSearchCallback(callback, response: self.makeEmptyFacetedResponse())
        })
    }
    
    func sendEvent(callback: @escaping (_ recommendation: [RecommendationModel]) -> Void) {
        SegmentifyConnectionManager.sharedInstance.request(requestModel: eventRequest, success: {(response: [String:AnyObject]) in
            
            guard let responses = response["responses"] as? [[Dictionary<AnyHashable,Any>]] else {
                print("error : \(response["statusCode"]! as Any)")
                return
            }
            self.recommendations.removeAll()
            
            if(responses.isEmpty){
                print("error : response is not valid or empty")
                return
            }
            else{
                for (_, obj) in responses[0].enumerated() {
                    self.minusIndex = Int()
                    guard let params = obj["params"] as? Dictionary<AnyHashable, Any> else {
                        return
                    }
                    self.params = params
                    
                    self.type = obj["type"] as? String
                    
                    guard self.type == "recommendProducts"  else {
                        print("type is not valid")
                        return
                    }
                    
                    guard let dynamicItems = self.params!["dynamicItems"] as? String else {
                        print("params['dynamicItems'] is not valid")
                        return
                    }
                    
                    guard let dynamicDic = SegmentifyTools.convertStringToDictionary(text: dynamicItems) else {
                        print("cannot converted string to json")
                        return
                    }
                    
                    guard let recommendedProducts = self.params!["recommendedProducts"] as? Dictionary<AnyHashable, Any> else {
                        print("params['recommendedProducts'] is not valid")
                        return
                    }
                    self.recommendationArray = recommendedProducts
                    
                    guard let notificationTitle = self.params!["notificationTitle"] as? String else {
                        print("params['notificationTitle'] is not valid")
                        return
                    }
                    
                    guard let staticItems = self.params!["staticItems"] as? String else {
                        print("params['dynamicItems'] is not valid")
                        return
                    }
                    
                    guard let staticItemsDic = SegmentifyTools.convertStringToDictionary(text: staticItems) else {
                        print("cannot converted string to json")
                        return
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
                        if let recoomendationSource = object["recommendationSource"] {
                            self.recommendationSourceKeys.append(recoomendationSource as! String)
                            dynObj.recommendationSource = recoomendationSource as? String
                            key = "\(object["recommendationSource"]!)"
                        }
                        
                        if let itemCount = object["itemCount"] {
                            self.itemCounts.append(itemCount as! String)
                            dynObj.itemCount = Int(itemCount as! String)
                        }

                        let timeFrameKey = object["timeFrame"]
                        
                        if timeFrameKey != nil {
                            self.timeFrameKeys.append(timeFrameKey as! String)
                            dynObj.timeFrame = timeFrameKey as? String
                            key = key + "|\(object["timeFrame"]!)"
                            let scoreKey = object["score"]
                            //Score key
                            if scoreKey != nil {
                                self.scoreKeys.append(scoreKey as! String)
                                dynObj.score = scoreKey as? String
                                key = key + "|\(object["score"]!)"
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
            let errorRecModel = RecommendationModel()
            errorRecModel.errorString = "error"
            callback(self.recommendations)
        })
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
                        self.createRecomendation(title: notificationTitle, itemCount: dynObj.itemCount!, products: products,interactionId: interactionId,impressionId: impressionId)
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
                        
                        self.createRecomendation(title: notificationTitle, itemCount: dynObj.itemCount!, products: products,interactionId: interactionId,impressionId: impressionId)
                        var counter = 0
                        for product in currentRecModel.products!{
                            if newProdArray.contains(where: {$0.productId==product.productId}){ }
                            else {
                                if counter < dynObj.itemCount! {
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
            guard let assetTexts = searchAssetTexts as? [String:AnyObject] else {
                print(searchAssetTexts.self)
                return
            }
            var textMap = [String:SearchAssetTextModel]()
            for (key, val) in assetTexts {
                guard let assets = val as? Dictionary<AnyHashable,Any> else {
                    print(val.self)
                    return
                }
                let assetTexts = SearchAssetTextModel()
                
                if let popularProductsText = assets["popularProductsText"] {
                    assetTexts.popularProductsText = popularProductsText as! String
                }
                if let mobileCancelText = assets["mobileCancelText"] {
                    assetTexts.mobileCancelText = mobileCancelText as! String
                }
                if let notFoundText = assets["notFoundText"] {
                    assetTexts.notFoundText = notFoundText as! String
                }
                textMap[key as String] = assetTexts as SearchAssetTextModel;
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
        self.searcResponseProductsArray.removeAll()
        for (_, obj) in products.enumerated() {
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
            self.searcResponseProductsArray.append(proObj)
        }
        self.searchResponse.products = self.searcResponseProductsArray
    }
    
    private func createCategoryProducts(categoryProducts: Dictionary<AnyHashable, Any>){
        self.searchResponse.categoryProducts.removeAll()
        var _categoryProducts = [String:[ProductRecommendationModel]]()
        
        for(key, val) in categoryProducts {
            _categoryProducts.updateValue(val as! [ProductRecommendationModel], forKey: key as! String)
        }
        self.searchResponse.categoryProducts = _categoryProducts
    }
    
    private func createBrandProducts(brandProducts: Dictionary<AnyHashable, Any>){
        self.searchResponse.brandProducts.removeAll()
        var _brandProducts = [String:[ProductRecommendationModel]]()
        
        for(key, val) in brandProducts {
            _brandProducts.updateValue(val as! [ProductRecommendationModel], forKey: key as! String)
        }
        self.searchResponse.brandProducts = _brandProducts
    }
    
    private func createKeywordProducts(keywordProducts: Dictionary<AnyHashable, Any>){
        self.searchResponse.keywords.removeAll()
        var _keywordProducts = [String:[ProductRecommendationModel]]()
        
        for(key, val) in keywordProducts {
            _keywordProducts.updateValue(val as! [ProductRecommendationModel], forKey: key as! String)
        }
        self.searchResponse.keywords = _keywordProducts
    }
    
    private func createSearchCategories(categories: Dictionary<AnyHashable, Any>){
        self.searchResponse.categories.removeAll()
        var _categories = [String:String]()
        
        for(key, val) in categories {
            _categories.updateValue(val as! String, forKey: key as! String)
        }
        self.searchResponse.categories = _categories
    }
    
    private func createSearchBrands(brands: Dictionary<AnyHashable, Any>){
        self.searchResponse.brands.removeAll()
        var _brands = [String:String]()
        
        for(key, val) in brands {
            _brands.updateValue(val as! String, forKey: key as! String)
        }
        self.searchResponse.brands = _brands
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
        
        let encodedData = try? JSONEncoder().encode(segmentifyObject)
        let dataCenter  = SegmentifyManager.setup.dataCenterUrlPush
        var urlString = dataCenter! + "/native/subscription/push"
        if let authToken = SegmentifyManager.setup.authToken {
            // auth token will be used in header
        } else if let apiKey = SegmentifyManager.setup.apiKey {
            urlString += "?apiKey=" + apiKey
        } else {
            print("Error - you must provide either authToken or apiKey")
            return
        }
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authToken = SegmentifyManager.setup.authToken {
            request.setValue("Basic \(authToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = encodedData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let _ = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
        }
        task.resume()
    }

    open func sendNotificationInteraction(segmentifyObject : NotificationModel) {
        
        print("[Segmentify] sendNotificationInteraction called - type: \(segmentifyObject.type?.rawValue ?? "nil"), instanceId: \(segmentifyObject.instanceId ?? "nil"), interactionId: \(segmentifyObject.interactionId ?? "nil")")
        
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
            print("[Segmentify] Notification VIEW event - instanceId: \(instanceId!)")
        }

        if(segmentifyObject.type == NotificationType.CLICK){
            let instanceId = segmentifyObject.instanceId
            
            guard instanceId != nil  else {
                print("Error - you must fill instanceId or deviceToken before accessing sendNotification click event")
                return
            }
            

            UserDefaults.standard.set(segmentifyObject.instanceId, forKey: "SEGMENTIFY_PUSH_CAMPAIGN_ID")
            
            let interactionId = segmentifyObject.interactionId ?? instanceId!

            // Option B - SFY-20518
            // 1. Send type: "push-click" for click metrics (deduplicated)
            self.sendInteractionEvent(type: SegmentifyManager.pushClickStep, instanceId: instanceId!, interactionId: interactionId)
            
            // 2. Send type: "push" for attribution (stamps user record)
            self.sendInteractionEvent(type: SegmentifyManager.pushStep, instanceId: instanceId!, interactionId: interactionId)
            
            // In Option B, we don't call the native endpoint for clicks.
            return
        }

        let encodedData = try? JSONEncoder().encode(segmentifyObject)
        let dataCenter  = SegmentifyManager.setup.dataCenterUrlPush
        var urlString = dataCenter! + "/native/interaction/notification"
        if let authToken = SegmentifyManager.setup.authToken {
            // auth token will be used in header
        } else if let apiKey = SegmentifyManager.setup.apiKey {
            urlString += "?apiKey=" + apiKey
        } else {
            print("Error - you must provide either authToken or apiKey")
            return
        }
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authToken = SegmentifyManager.setup.authToken {
            request.setValue("Basic \(authToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = encodedData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let _ = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
        }
        task.resume()
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
        
        setIDAndSendEvent()
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
        
        setIDAndSendEvent()
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
        if self.eventRequest.sessionID == nil {
            self.getUserIdAndSessionIdRequest( success: { () -> Void in
                self.sendSearchEvent(callback: { (response: SearchModel) in
                    callback(response)
                })
            })
        } else {
            self.sendSearchEvent(callback: { (response: SearchModel) in
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
        
        if segmentifyObject.trigger != nil{
            eventRequest.trigger = segmentifyObject.trigger
        }
        if segmentifyObject.type != nil{
            eventRequest.type = segmentifyObject.type
        }
        if segmentifyObject.ordering != nil {
            eventRequest.ordering = segmentifyObject.ordering
        }
        if segmentifyObject.filters != nil {
            var filtersArray = [Any]()
            segmentifyObject.filters?.forEach {
                filter in
                filtersArray.append(filter.nsDictionary)
            }
            eventRequest.filters = filtersArray
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
        if self.eventRequest.sessionID == nil {
            self.getUserIdAndSessionIdRequest( success: { () -> Void in
                self.sendSearchFacetedEvent(callback: { (response: FacetedResponseModel) in
                    callback(response)
                })
            })
        } else {
            self.sendSearchFacetedEvent(callback: { (response: FacetedResponseModel) in
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
    
    private func sendInteractionEvent(type: String, instanceId: String, interactionId: String) {
        eventRequest.eventName = SegmentifyManager.interactionEventName
        eventRequest.type = type
        eventRequest.instanceId = instanceId
        eventRequest.interactionId = interactionId
        eventRequest.oldUserId = nil
        
        if let userSentId = UserDefaults.standard.object(forKey: "UserSentUserId") as? String {
            eventRequest.userID = userSentId
        } else if let segmentifyUserId = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String {
            eventRequest.userID = segmentifyUserId
        }
        
        print("[Segmentify] Sending interaction event - type: \(type), instanceId: \(instanceId), interactionId: \(interactionId), userId: \(eventRequest.userID ?? "nil"), sessionId: \(eventRequest.sessionID ?? "nil")")
        
        setIDAndSendEvent()
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
    
    //private func
    private func getUserIdAndSessionIdRequest(success : @escaping () -> Void) {
        
        var requestURL : URL!
        let dataCenterUrl:String = SegmentifyManager.setup.dataCenterUrl!
        if UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") != nil {
            requestURL = URL(string: dataCenterUrl + "/get/key?count=1")!
        } else {
            requestURL = URL(string: dataCenterUrl + "/get/key?count=2")!
        }
        let urlRequest: NSMutableURLRequest = NSMutableURLRequest(url: requestURL)
        let task = SegmentifyConnectionManager.urlSession.dataTask(with: urlRequest as URLRequest) {
            (data, response, error) -> Void in
            
            if response == nil {
                self.getUserIdAndSessionIdRequest( success: { () -> Void in
                    self.sendEvent(callback: { (response: [RecommendationModel]) in
                        //callback(response)
                    })
                })
            } else {
                let httpResponse = response as! HTTPURLResponse
                let statusCode = httpResponse.statusCode
                
                if (statusCode == 200) {
                    do{
                        if let jsonArray = try JSONSerialization.jsonObject(with: data!, options: []) as? NSArray {
                            
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
                                    self.initSessionId(sessionId: jsonArray[1] as? String)
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
                        success()
                    }catch {
                        print("Error with Json: \(error)")
                    }
                }
            }
        }
        task.resume()
    }

    func testingPrepareNetworkSession(
        userId: String = "test-user",
        sessionId: String = "test-session"
    ) {
        eventRequest.userID = userId
        eventRequest.sessionID = sessionId
    }

    func testingClearNetworkSession() {
        eventRequest.sessionID = nil
        eventRequest.userTraitsProperties = nil
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
            getUserIdAndSessionIdRequest {
                completion(self.eventRequest.userID, self.eventRequest.sessionID)
            }
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

public func daysBetween(start: Date, end: Date) -> Int {
    return Calendar.current.dateComponents([.day], from: start, to: end).day!
}
