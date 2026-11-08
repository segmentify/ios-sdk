//
//  ProductModel.swift
//  Segmentify

import Foundation
import UIKit

public class NotificationModel: Codable {

    
    public var deviceToken:String?
    public var instanceId:String?
    public var interactionId:String?
    /// The send request's correlationId from the push (`userInfo["correlationId"]`); sent back on VIEW/CLICK.
    public var correlationId:String?
    public var firebaseServerKey:String?
    public var type:NotificationType?
    public var topic:String?
    public var params:[String:String] = [String:String]()
    public var userId : String?
    public var providerType:ProviderType?
    public var sdkVersion:String?
    private var email:String?
    private var userName:String?
    private var osVersion:String?
    private var os:String?

    public init() {
        
        if(self.type != NotificationType.PERMISSION_INFO){
            self.deviceToken = nil
        }
        
        self.os = "IOS"
        self.osVersion = UIDevice.current.systemVersion
        self.userId = UserDefaults.standard.object(forKey: "SEGMENTIFY_USER_ID") as? String
        
        let email_ = UserDefaults.standard.object(forKey: "SEGMENTIFY_EMAIL") as? String
        let username_ = UserDefaults.standard.object(forKey: "SEGMENTIFY_USERNAME") as? String
        
        if(email_?.isEmpty == false){  self.email = email_}
        if(username_?.isEmpty == false){  self.userName = username_}
        
        if(self.firebaseServerKey?.isEmpty == true){ self.providerType = ProviderType.APNS } else { self.providerType = ProviderType.FIREBASE}
        
    }

    /// Builds a VIEW/CLICK model from a Segmentify push's `userInfo`,
    /// copying instanceId and correlationId so shown/clicked can be tied to the send request,
    /// and the provider (FIREBASE/APNS) inferred from the payload so VIEW and CLICK report the same one.
    public static func fromPush(userInfo: [AnyHashable: Any], type: NotificationType) -> NotificationModel {
        let payload = SegmentifyPushPayload(userInfo: userInfo)
        let model = NotificationModel()
        model.type = type
        model.instanceId = payload.instanceId
        model.correlationId = payload.correlationId
        model.providerType = payload.providerType
        return model
    }
}

