//
//  SegmentifyRegisterRequest.swift
//  Segmentify

import Foundation
import UIKit
import CoreTelephony

public class SegmentifyRegisterRequest : NSObject,SegmentifyRequestProtocol {
    var path = "subscription"
    var port = "4243"
    var method = "POST"
    var subdomain = ""
    var dataCenterUrl:String = ""
    var apiKey:String?
    var authHeader:String?
    
    var segmentifyObj:SegmentifyObject?
    
    var token:String?
    var os:String?
    var osVersion:String?
    var deviceType:String?
    var deviceName:String?
    var carrier:String = ""
    var local:String?
    var appVersion:String?
    var sdkVersion:String?
    var firstTime:NSNumber?
    var advertisingIdentifier:String?
    var category:String?
    var categories : [String]?
    var subCategory:String?
    var eventName:String?
    var productID:String?
    var title:String?
    var brand:String?
    var recommendIds:[String]?
    var currency:String?
    var price:NSNumber?
    var oldPrice:NSNumber?
    var totalPrice:NSNumber?
    var inStock:Bool?
    var basketStep:String?
    var wishlistStep:String?
    var favoritesList:[String]?
    var basketID:String?
    var quantity:NSNumber?
    var orderNo:String?
    var products:[Any]?
    var checkoutStep:String?
    var username:String?
    var externalId:String?
    var userID:String?
    var sessionID:String?
    var email:String?
    var age:String?
    var birthdate:String?
    var gender:String?
    var fullName:String?
    var mobilePhone:String?
    var isRegistered:Bool?
    var isLogin:Bool?
    var userOperationStep:String?
    var pageUrl:String?
    var image:String?
    var url:String?
    var memberSince:String?
    var lastSearchDeletedKeywords:String?
    var oldUserId:String?
    var lang:String?
    var mUrl:String?
    var imageXS:String?
    var imageS:String?
    var imageM:String?
    var imageL:String?
    var imageXL:String?
    var colors:[String]?
    var sizes:[String]?
    var labels:[String]?
    var location:String?
    var segments:[String]?
    var type:String?
    var params:[String:AnyObject]?
    var instanceId:String?
    var interactionId:String?
    var deeplink:String?
    var icon:String?
    var noUpdate:Bool?
    var testMode:Bool?
    var query:String?
    var region:String?
    // bannerify related objects
    var activeBanners:[Any]?
    var group:String?
    var banners:[Any]?
    var order:NSNumber?
    var urls:[String]?
    var label:String?
    var trigger:String?
    var ordering:FacetedOrdering?
    var filters:[Any]?
    var userTraitsProperties: [String: Any]?
    
    var extra: [AnyHashable: Any] = [AnyHashable: Any]()
    
    override init() {
        let device = UIDevice.current
        
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let deviceType = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else {
                return identifier
            }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        let provider = CTTelephonyNetworkInfo.init().subscriberCellularProvider
        
        if let code = provider?.mobileCountryCode {
            if let networkCode = provider?.mobileNetworkCode {
                self.carrier = "\(code)\(networkCode)"
            }
        }
        
        self.deviceType = deviceType
        self.os = device.systemName
        self.lang = "EN"
        self.osVersion = device.systemVersion
        self.deviceName = device.name
        self.local = NSLocale.preferredLanguages.first
        self.firstTime = NSNumber.init(value: 1)
        self.region = ""
    }
    
    init(withDictionary dictionary: Dictionary<AnyHashable, Any>) {
        self.token = dictionary["token"] as? String
        self.apiKey = dictionary["apiKey"] as? String
        self.os = dictionary["os"] as? String
        self.osVersion = dictionary["osVersion"] as? String
        self.deviceType = dictionary["deviceType"] as? String
        self.deviceName = dictionary["deviceName"] as? String
        if let c = dictionary["carrier"] {
            self.carrier = c as! String
        }
        else {
            self.carrier = ""
        }
        self.local = dictionary["local"] as? String
        self.appVersion = dictionary["appVersion"] as? String
        self.sdkVersion = dictionary["sdkVersion"] as? String
        self.firstTime = dictionary["firstTime"] as? NSNumber
        self.advertisingIdentifier = dictionary["advertisingIdentifier"] as? String
    }
    
    
    func clearVariables(){
        self.category = nil
        self.categories = nil
        self.subCategory = nil
        self.eventName = nil
        self.productID = nil
        self.title = nil
        self.brand = nil
        self.currency = nil
        self.price = nil
        self.oldPrice = nil
        self.totalPrice = nil
        self.inStock = nil
        self.basketStep = nil
        self.wishlistStep = nil
        self.favoritesList = nil
        self.basketID = nil
        self.quantity = nil
        self.orderNo = nil
        self.products = nil
        self.checkoutStep = nil
        self.username = nil
        self.externalId = nil
        self.userID = nil
        self.sessionID = nil
        self.email = nil
        self.age = nil
        self.birthdate = nil
        self.gender = nil
        self.fullName = nil
        self.mobilePhone = nil
        self.isRegistered = nil
        self.isLogin = nil
        self.userOperationStep = nil
        self.pageUrl = nil
        self.image = nil
        self.url = nil
        self.memberSince = nil
        self.lastSearchDeletedKeywords = nil
        self.oldUserId = nil
        self.lang = nil
        self.mUrl = nil
        self.imageXS = nil
        self.imageS = nil
        self.imageM = nil
        self.imageL = nil
        self.imageXL = nil
        self.colors = nil
        self.sizes = nil
        self.labels = nil
        self.location = nil
        self.segments = nil
        self.type = nil
        self.params = nil
        self.instanceId = nil
        self.interactionId = nil
        self.noUpdate = nil
        self.testMode = nil
        self.query = nil
        self.region = nil
        // bannerify related parameters
        self.activeBanners = nil
        self.group = nil
        self.banners = nil
        self.order = nil
        self.urls = nil
        self.trigger = nil
        self.ordering = nil
        self.filters = nil
        self.userTraitsProperties = nil
    }
    
    
    func toDictionary() -> Dictionary<AnyHashable, Any> {
        if let eventName = self.eventName,
           !CdpEventName.eventsWithProperties.contains(eventName) {
            self.userTraitsProperties = nil
        }
        var dictionary = [AnyHashable: Any]()
        
        if let token = self.token {
            dictionary["token"] = token as Any?
        }
        
        dictionary["apiKey"] = apiKey as Any?
        
        dictionary["os"] = "ios"
        dictionary["device"] = "ios"

        if let osVersion = self.osVersion {
            dictionary["osversion"] = osVersion as Any?
        }
        if let deviceType = self.deviceType {
            dictionary["deviceType"] = deviceType as Any?
        }
        if let deviceName = self.deviceName {
            dictionary["deviceName"] = deviceName as Any?
        }
        
        dictionary["carrier"] = carrier as Any?
        
        if let local = self.local {
            dictionary["local"] = local as Any?
        }
        if let appVersion = self.appVersion {
            dictionary["appVersion"] = appVersion as Any?
        }
        if let sdkVersion = self.sdkVersion {
            dictionary["sdkVersion"] = sdkVersion as Any?
        }
        if let firstTime = self.firstTime {
            dictionary["firstTime"] = firstTime.uintValue as Any?
        }
        
        if let advertisingIdentifier = self.advertisingIdentifier {
            dictionary["advertisingIdentifier"] = advertisingIdentifier as Any?
        }
        
        if let eventName = self.eventName {
            dictionary["name"] = eventName as Any?
        }
        
        if let testMode = self.testMode {
            dictionary["testMode"] = testMode as Any?
        }else{
            dictionary["testMode"] = nil
        }
        
        if self.eventName == "SEARCH" {
            dictionary["query"] = query
        }
        
        if self.eventName == "PAGE_VIEW" {
            dictionary["category"] = category as Any?
        }

        if self.eventName == "PAGE_VIEW" {
            dictionary["subCategory"] = subCategory as Any?
        }

        if self.eventName == "PRODUCT_VIEW" || self.eventName == "BASKET_OPERATIONS" || self.eventName == "WISHLIST" {
            dictionary["productId"] = productID as Any?
        } else {
            dictionary["productId"] = nil
        }

        if self.eventName == "PRODUCT_VIEW" {
            dictionary["title"] = title as Any?
        } else {
            dictionary["title"] = nil
        }

        if self.eventName == "PRODUCT_VIEW" {
            dictionary["brand"] = brand as Any?
        } else {
            dictionary["brand"] = nil
        }

        if self.eventName == "PRODUCT_VIEW" || self.eventName == "BASKET_OPERATIONS" {
            dictionary["price"] = price as Any?
        } else {
            dictionary["price"] = nil
        }

        if (self.eventName == "CHECKOUT" && self.basketStep != nil) || (self.eventName == "CHECKOUT" && self.checkoutStep != nil) {
            dictionary["totalPrice"] = totalPrice as Any?
        } else {
            dictionary["totalPrice"] = nil
        }

        if self.eventName == "PRODUCT_VIEW" {
            dictionary["gender"] = gender as Any?
        } else {
            dictionary["gender"] = nil
        }

        if self.eventName == "PRODUCT_VIEW" {
            dictionary["noUpdate"] = noUpdate as Any?
        } else {
            dictionary["noUpdate"] = nil
        }
        
        if let lang = self.lang {
            dictionary["lang"] = lang as Any?
        }

        if let region = self.region {
            dictionary["region"] = region as Any?
        } else {
            dictionary["region"] = ""
        }

        if let currency = self.currency {
            dictionary["currency"] = currency as Any?
        } else {
            dictionary["currency"] = nil
        }

        if (self.eventName == "CHECKOUT" && self.basketStep != nil) || self.eventName == "BASKET_OPERATIONS" {
            dictionary["quantity"] = quantity as Any?
        } else {
            dictionary["quantity"] = nil
        }

        if let recommendIds = self.recommendIds {
            dictionary["recommendIds"] = recommendIds as Any?
        } else {
            dictionary["recommendIds"] = nil
        }

        if self.eventName == "CHECKOUT" {
            dictionary["basketId"] = basketID as Any?
        } else {
            dictionary["basketId"] = nil
        }

        if self.eventName == "CHECKOUT" {
            dictionary["productList"] = products as Any
        } else {
            dictionary["productList"] = nil
        }
        
        if let userID = self.userID {
            dictionary["userId"] = userID as Any?
        }
        
        if let sessionId = self.sessionID as Any? {
            dictionary["sessionId"] = sessionId as Any?
        }

        if let pageUrl = self.pageUrl {
            dictionary["pageUrl"] = pageUrl
        } else {
            dictionary["pageUrl"] = nil
        }

        if self.eventName == "PRODUCT_VIEW" {
            dictionary["oldPrice"] = oldPrice
        } else {
            dictionary["oldPrice"] = nil
        }

        if self.eventName == "PRODUCT_VIEW" {
            dictionary["inStock"] = inStock
        } else {
            dictionary["inStock"] = nil
        }

        if self.eventName == "PRODUCT_VIEW" {
            dictionary["image"] = image
        } else {
            dictionary["image"] = nil
        }

        if self.eventName == "PRODUCT_VIEW" {
            dictionary["categories"] = categories
        }
        
        if self.eventName == "PRODUCT_VIEW" {
            dictionary["category"] = category as Any?
        }
        
        if let url = self.url {
            dictionary["url"] = url
        }
        
        if let mUrl = self.mUrl {
            dictionary["mUrl"] = mUrl
        } else {
            dictionary["mUrl"] = nil
        }
        
        if self.eventName == "CHECKOUT" && checkoutStep != nil{
            dictionary["step"] = self.checkoutStep
        }
        
        if self.eventName == "BASKET_OPERATIONS" && basketStep != nil{
            dictionary["step"] = self.basketStep
        }

        if self.eventName == "WISHLIST" && wishlistStep != nil {
            dictionary["step"] = self.wishlistStep
        }

        if self.eventName == "WISHLIST" && favoritesList != nil {
            dictionary["favoritesList"] = self.favoritesList
        } else {
            dictionary["favoritesList"] = nil
        }

        if self.eventName == "CHECKOUT" && basketStep != nil {
            dictionary["orderNo"] = orderNo
        } else {
            dictionary["orderNo"] = nil
        }
        
        if self.eventName == "USER_OPERATIONS" && self.userOperationStep != nil {
            dictionary["step"] = userOperationStep
        }

        if self.eventName == "USER_OPERATIONS" {
            dictionary["username"] = username
        } else {
            dictionary["username"] = nil
        }
        
        if self.eventName == "USER_OPERATIONS" {
            dictionary["externalId"] = externalId
        } else {
            dictionary["externalId"] = nil
        }

        if self.eventName == "USER_OPERATIONS" {
            dictionary["email"] = email
        } else {
            dictionary["email"] = nil
        }

        if self.eventName == "USER_OPERATIONS" {
            dictionary["phone"] = mobilePhone
        } else {
            dictionary["phone"] = nil
        }

        if self.eventName == "USER_OPERATIONS" {
            dictionary["fullName"] = fullName
        } else {
            dictionary["fullName"] = nil
        }

        if self.eventName == "USER_OPERATIONS" {
            dictionary["segments"] = segments
        } else {
            dictionary["segments"] = nil
        }

        if self.eventName == "USER_OPERATIONS" {
            dictionary["location"] = location
        } else {
            dictionary["location"] = nil
        }

        if self.eventName == "USER_OPERATIONS" {
            dictionary["isLogin"] = isLogin
        } else {
            dictionary["isLogin"] = nil
        }

        if self.eventName == "USER_OPERATIONS" {
            dictionary["isRegistered"] = isRegistered
        } else {
            dictionary["isRegistered"] = nil
        }

        if self.eventName == "USER_OPERATIONS" {
            dictionary["age"] = age as Any?
        } else {
            dictionary["age"] = nil
        }

        if self.eventName == "USER_OPERATIONS" {
            dictionary["memberSince"] = memberSince as Any?
        } else {
            dictionary["memberSince"] = nil
        }

        if self.eventName == "USER_OPERATIONS" {
            dictionary["lastSearchDeletedKeywords"] = lastSearchDeletedKeywords as Any?
        } else {
            dictionary["lastSearchDeletedKeywords"] = nil
        }

        if self.eventName == "INTERACTION" {
            dictionary["interactionId"] = interactionId
            dictionary["deeplink"] = deeplink
            dictionary["icon"] = icon
        } else {
            dictionary["interactionId"] = nil
            dictionary["deeplink"] = nil
            dictionary["icon"] = nil
        }

        if self.eventName == "INTERACTION" {
            dictionary["instanceId"] = instanceId
        } else {
            dictionary["instanceId"] = nil
        }

        if self.eventName == "INTERACTION" || self.eventName == "CUSTOM_EVENT" {
            dictionary["type"] = type
        } else {
            dictionary["type"] = nil
        }

        if self.eventName == "BANNER_OPERATIONS" || self.eventName == "BANNER_GROUP_VIEW" || self.eventName == "INTERNAL_BANNER_GROUP" {
            if self.activeBanners != nil{
                dictionary["activeBanners"] = activeBanners as Any?
            } else {
                dictionary["activeBanners"] = nil
            }
            if self.group != nil {
                dictionary["group"] = group as Any?
            } else {
                dictionary["group"] = nil
            }
            if self.banners != nil {
                dictionary["banners"] = banners as Any?
            } else {
                dictionary["banners"] = nil
            }
            if self.order != nil{
                dictionary["order"] = order as Any?
            } else {
                dictionary["order"] = nil
            }
            if self.urls != nil {
                dictionary["urls"] = urls as Any?
            } else {
                dictionary["urls"] = nil
            }
            if self.title != nil {
                dictionary["title"] = title as Any
            } else {
                dictionary["title"] = nil
            }
            if self.productID != nil {
                dictionary["productId"] = productID as Any
            } else {
                dictionary["productId"] = nil
            }
            if self.category != nil {
                dictionary["category"] = category as Any
            }
            if self.brand != nil {
                dictionary["brand"] = brand as Any
            } else {
                dictionary["brand"] = nil
            }
            if self.label != nil {
                dictionary["label"] = label as Any
            } else {
                dictionary["label"] = nil
            }
            if self.type != nil {
                dictionary["type"] = type
            } else {
                dictionary["type"] = nil
            }
        }
        
        if self.eventName == "PRODUCT_VIEW" || self.eventName == "CHECKOUT" || self.eventName == "BASKET_OPERATIONS" || self.eventName == "WISHLIST" {
            if self.activeBanners != nil{
                dictionary["activeBanners"] = activeBanners as Any?
            } else {
                dictionary["activeBanners"] = nil
            }
        } else {
            dictionary["activeBanners"] = nil
        }

        if let params = self.params {
            dictionary["params"] = params
        } else {
            dictionary["params"] = nil
        }
        
        dictionary["extra"] = extra as Any?
        
        if self.eventName == "SEARCH" {
            dictionary["type"] = type
            dictionary["trigger"] = trigger
            dictionary["ordering"] = ordering?.dictionary
            if self.filters != nil{
                dictionary["filters"] = filters as Any?
            } else {
                dictionary["filters"] = nil
            }
        }

        if let eventName = self.eventName,
           CdpEventName.eventsWithProperties.contains(eventName),
           let userTraitsProperties = self.userTraitsProperties {
            dictionary["properties"] = userTraitsProperties
        }
        return dictionary
    }
    
    convenience init?(withJsonString jsonString: String) {
        let dictionary = SegmentifyTools.convertJsonStringToDictionary(text: jsonString)
        guard dictionary != nil else {
            return nil
        }
        self.init(withDictionary: dictionary!)
    }
    
    func toJsonString() -> String? {
        let dictionary = self.toDictionary()
        if let string = SegmentifyTools.convertDictionaryToJsonString(dictionary: dictionary) {
            return string
        }
        return nil
    }
}


