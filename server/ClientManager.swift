//
//  ClientManager.swift
//  Cupid
//
//  Created by panzhijun on 2019/4/19.
//  Copyright © 2019 panzhijun. All rights reserved.
//

import UIKit
import SwiftSocket
import RealmSwift

protocol ClientManagerDelegate : class {
    
    // 处理群聊
    func sendMsgToClient(_ data : Data)
    func removeClient(_ client : ClientManager)
    
    // 处理单聊
    func sendMsgToClientHandleSingleChat(_ data : Data,fromeId : String,toId : String, chatId : String)
    
    
   // 处理离线消息
    func sendOfflineMsg(data: Data,toId : String)
}


class ClientManager: NSObject {
   var tcpClient : TCPClient
    weak var delegate : ClientManagerDelegate?
    
    fileprivate var isClientConnected : Bool = false
    fileprivate var heartTimeCount : Int = 0
    
    

    
    init(tcpClient : TCPClient) {
        self.tcpClient = tcpClient
    }
}

extension ClientManager {
    func startReadMsg(dicClient : inout Dictionary<String,Any>) {
        isClientConnected = true
        
        let timer = Timer(fireAt: Date(), interval: 1, target: self, selector: #selector(checkHeartBeat), userInfo: nil, repeats: true)
        RunLoop.current.add(timer, forMode: RunLoop.Mode.common)
        timer.fire()
        
        while isClientConnected {
            if let lMsg = tcpClient.read(4) {
                // 1.读取长度的data
                let headData = Data(bytes: lMsg, count: 4)
                var length : Int = 0
                (headData as NSData).getBytes(&length, length: 4)
                
                // 2.读取类型
                guard let typeMsg = tcpClient.read(2) else {
                    return
                }
                let typeData = Data(bytes: typeMsg, count: 2)
                var type : Int = 0
                (typeData as NSData).getBytes(&type, length: 2)
                
                // 3.根据长度, 读取真实消息
                guard let msg = tcpClient.read(length) else {
                    return
                }
                let data = Data(bytes: msg, count: length)
                
                // 完整数据 转发给客户端
                var totalData = headData + typeData + data
                

                print("类型\(type)  -- 心跳(100) 进入(0) 离开(1) 消息(2) ")
                // 进入会话
                if type == 0 {
                    // 数据转成聊天数据
                    let chatMsg = try! ProtoUser.parseFrom(data: data)
                    // 更新字典数据
                    dicClient.updateValue(tcpClient, forKey: chatMsg.objectId)
                    print("\(String(describing: chatMsg.name)) 进入回话页面")
                    
                    // 进入会话查看是否有离线消息
                    delegate?.sendOfflineMsg(data: data, toId: chatMsg.objectId)
                }
                else if type == 1 {
                    // 离开回话
                    tcpClient.close()
                    delegate?.removeClient(self)
                    // 数据转成聊天数据
                    let chatMsg = try! ProtoUser.parseFrom(data: data)
                    // 更新字典数据
                    guard let index = dicClient.index(forKey: chatMsg.objectId) else {return}
                    dicClient.remove(at: index)
                    
                    print("\(String(describing: chatMsg.name)) 离开回话页面")
                    continue
                    
                } else if type == 100 {
                    // 心跳包
                    heartTimeCount = 0
                    continue
                } else if type == 10 {
                    // 获取聊天列表
                    print("获取聊天列表")
                } else if type == 2 {
                    
                    // 数据转成聊天数据
                    let chatMsg = try! ProtoMessage.parseFrom(data: data)
                    // 是否包含这个聊天Id
                    let chatType = chatMsg.recipientId
                    print("\(chatMsg.senderName) 发送了消息：\(chatMsg.text)")
                    // 单聊
                    if chatType != nil {
                        // 转发消息
                        delegate?.sendMsgToClientHandleSingleChat(totalData, fromeId: chatMsg.senderId, toId: chatMsg.recipientId,chatId: chatMsg.chatId)
                        continue
                        
                    }
                
                } else if type == 200 {
                    
                    // 登录
                   let chatMsg = String(data: data, encoding: .utf8)
                    
                    let predicate = "phone = '\(chatMsg!)'"
                    
                  let messages : Results<DBUser>  = RealmTool.getUserByPredicate(predicate)
                    let dbUser : DBUser = messages.first!
                    
                    let protoUser = ProtoUser.Builder()
                    protoUser.objectId = dbUser.objectId
                    protoUser.phone = dbUser.phone
                    protoUser.name = dbUser.name
                    protoUser.nickName = dbUser.nickName
                    protoUser.country = dbUser.country
                    protoUser.status = dbUser.status
                    protoUser.picture = dbUser.picture
                    protoUser.thumbnail = dbUser.thumbnail
                    protoUser.lastActive = dbUser.lastActive
                    protoUser.lastTerminate = dbUser.lastTerminate
                    protoUser.createdAt = dbUser.createdAt
                    protoUser.updatedAt = dbUser.updatedAt
                    protoUser.gender = dbUser.gender
                    let msgData = (try! protoUser.build()).data()
                    
                    totalData =  toTotalData(data: msgData, type: type)
                }
                else if type == 201 {
                    
                    // 获取好友列表
                    let friends : Results<DBFriend>  = RealmTool.getFriendList()
                    
                    var array : [Any] = [Any]()
                    
                    
                    for item in friends {
                        let dbFriend = item
                        
                        let protoFriend = ProtoFriend.Builder()
                        protoFriend.objectId = dbFriend.objectId
                        protoFriend.friendId = dbFriend.friendId
                        protoFriend.section = dbFriend.section
                        protoFriend.isDeleted = dbFriend.isDeleted
                        
                        protoFriend.createdAt = dbFriend.createdAt
                        protoFriend.updatedAt = dbFriend.updatedAt
                        protoFriend.name = dbFriend.name
                        protoFriend.picture = dbFriend.picture
                        let msgData = (try! protoFriend.build()).data()
                        
                        
                        array.append(msgData)
                        
//                        totalData =  toTotalData(data: msgData, type: type)
//                        delegate?.sendMsgToClient(totalData)
                        
                    }
                    let msgData = NSKeyedArchiver.archivedData(withRootObject: array)
                    
                    totalData =  toTotalData(data: msgData, type: type)
                    delegate?.sendMsgToClient(totalData)
                    continue
                    
                }
                else if type == 202 {
                    
                    // 获取好友详细信息
                    let chatMsg = String(data: data, encoding: .utf8)
                    
                    let predicate = "phone = '\(chatMsg!)'"
                    
                    let messages : Results<DBUser>  = RealmTool.getUserByPredicate(predicate)
                    let dbUser : DBUser = messages.first!
                    
                    let protoUser = ProtoUser.Builder()
                    protoUser.objectId = dbUser.objectId
                    protoUser.phone = dbUser.phone
                    protoUser.name = dbUser.name
                    protoUser.nickName = dbUser.nickName
                    protoUser.country = dbUser.country
                    protoUser.status = dbUser.status
                    protoUser.picture = dbUser.picture
                    protoUser.thumbnail = dbUser.thumbnail
                    protoUser.lastActive = dbUser.lastActive
                    protoUser.lastTerminate = dbUser.lastTerminate
                    protoUser.createdAt = dbUser.createdAt
                    protoUser.updatedAt = dbUser.updatedAt
                    protoUser.gender = dbUser.gender
                    
                    let msgData = (try! protoUser.build()).data()
                    
                    totalData =  toTotalData(data: msgData, type: type)
                }
                
                delegate?.sendMsgToClient(totalData)
                
            } else {
                self.removeClient()
            }
        }
    }
    
    @objc fileprivate func checkHeartBeat() {
        heartTimeCount += 1
        if heartTimeCount >= 10 {
            self.removeClient()
        }
    }
    
    private func removeClient() {
        delegate?.removeClient(self)
        isClientConnected = false
        print("客户端断开了连接  \(tcpClient.address)")
        tcpClient.close()
    }
    
    
    func toTotalData(data : Data, type : Int) -> Data{
        // 1.将消息长度, 写入到data
        var length = data.count
        let headerData = Data(bytes: &length, count: 4)
        
        // 2.消息类型
        var tempType = type
        let typeData = Data(bytes: &tempType, count: 2)
        
        // 3.发送消息
        let totalData = headerData + typeData + data
      
        return totalData
    }
}
