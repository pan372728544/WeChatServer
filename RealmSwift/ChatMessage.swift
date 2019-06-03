//
//  ChatMessage.swift
//  Cupid
//
//  Created by panzhijun on 2019/4/28.
//  Copyright © 2019 panzhijun. All rights reserved.
//

import UIKit
import RealmSwift




class ChatMessage: Object {

    @objc dynamic var key : String? = ""
    @objc dynamic var chatData : Data?

}


class DBUser: Object {
    
    // 用户信息搜索的id
    @objc dynamic var objectId = ""
    
    @objc dynamic var phone = ""
    
    @objc dynamic var name = ""
    @objc dynamic var nickName = ""
    
    @objc dynamic var country = ""
    
    @objc dynamic var status = ""
    
    @objc dynamic var picture = ""
    @objc dynamic var thumbnail = ""
    
    
    @objc dynamic var lastActive: Int64 = 0
    @objc dynamic var lastTerminate: Int64 = 0
    
    @objc dynamic var createdAt: Int64 = 0
    @objc dynamic var updatedAt: Int64 = 0
    @objc dynamic var gender = ""
    
    override static func primaryKey() -> String? {
        
        return "objectId"
    }
    
}


class DBFriend: Object {
    
    @objc dynamic var objectId = ""
    
    @objc dynamic var friendId = ""
    
    @objc dynamic var section = ""
    @objc dynamic var name = ""
    
    @objc dynamic var picture = ""
    
    @objc dynamic var isDeleted = false
    
    @objc dynamic var createdAt: Int64 = 0
    @objc dynamic var updatedAt: Int64 = 0

    override static func primaryKey() -> String? {
        
        return "objectId"
    }
    
}



