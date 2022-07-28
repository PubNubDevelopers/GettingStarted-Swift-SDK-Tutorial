//
//  ContentView.swift
//  Getting Started Swift Chat
//
//  Created by Darryn Campbell on 26/07/2022.
//

import SwiftUI
import PubNub

//  todo tidy code
//  todo bring comments over from Android
//  todo check into git
//  todo github readme

struct ContentView: View {
    @ObservedObject var viewModel: ChatViewModel = ChatViewModel()
    @Environment(\.scenePhase) var scenePhase
    
    let groupChatChannel: String = "group_chat"
    
    var body: some View {
        VStack (alignment: .leading, spacing: 0) {
            Header(viewModel: viewModel)
            MessageList(viewModel: viewModel)
            //Spacer()
            MessageInput(viewModel: viewModel).padding()
            Spacer()
        }
        //.ignoresSafeArea()
        .onAppear(){
            print("appear")
            applicationLaunched(viewModel: viewModel)
        }
        .onDisappear() {
            print("disappear")
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                print("active")
                applicationBroughtToForeground(viewModel: viewModel)
            }
            else if newPhase == .inactive {
                print("inactive")
                applicationSentToBackground(viewModel: viewModel)
            }
            else if newPhase == .background {
                print("background")
            }
        }
    }
    
    func applicationLaunched(viewModel: ChatViewModel)
    {
        initializePubNub(viewModel: viewModel)
    }
    
    func applicationBroughtToForeground(viewModel: ChatViewModel)
    {
        //  Subscribe
        viewModel.pubnub?.subscribe(to: [groupChatChannel], withPresence: true)
        
        viewModel.listener = SubscriptionListener()
        viewModel.listener?.didReceiveSubscription = {
            event in
            switch event {
            case let .messageReceived(message):
                
                let messageText: String = message.payload.stringOptional ?? ""
                let messageTimestamp: String = String(message.published)
                let sender: String = message.publisher ?? ""
                
                var newMsg = Message(message: messageText, senderDeviceId: sender, timetoken: String(message.published))
                let dateFormatter = DateFormatter()
                dateFormatter.timeStyle = DateFormatter.Style.medium
                dateFormatter.dateStyle = DateFormatter.Style.medium
                dateFormatter.timeZone = .current
                let secsSince1970: Double = message.published.timetokenDate.timeIntervalSince1970
                newMsg.humanReadableTime = dateFormatter.string(from: Date(timeIntervalSince1970: secsSince1970))

                viewModel.messages.append(newMsg)
                

            case let .connectionStatusChanged(status):
              print("Status Received: \(status)")
                if (status == ConnectionStatus.connected)
                {
                    let newMembership = PubNubMembershipMetadataBase(uuidMetadataId: viewModel.deviceId ?? "defaultId", channelMetadataId: groupChatChannel)
                    viewModel.pubnub?.setMemberships(
                        uuid: viewModel.deviceId,
                        channels: [newMembership]) { result in
                            switch result {
                            case .success(_):
                                print("setMemberships success")
                            case .failure(_):
                                print("setMemberships Error")
                            }
                        }

                    viewModel.pubnub?.fetchMessageHistory(for: [groupChatChannel], includeMeta: true, includeUUID: true, page: PubNubBoundedPageBase(limit: 8)) { result in
                        switch result {
                        case let .success(response):
                            if let myChannelMessages = response.messagesByChannel[groupChatChannel] {
                                print("history")
                                myChannelMessages.forEach { historicalMessage in
                                    print(historicalMessage)
                                    var newMsg = Message()
                                    newMsg.message = historicalMessage.payload.stringOptional ?? "Not found"
                                    newMsg.senderDeviceId = historicalMessage.publisher?.stringOptional ?? "Unknown"
                                    newMsg.timetoken = String(historicalMessage.published)
                                    let dateFormatter = DateFormatter()
                                    dateFormatter.timeStyle = DateFormatter.Style.medium
                                    dateFormatter.dateStyle = DateFormatter.Style.medium
                                    dateFormatter.timeZone = .current
                                    //newMsg.timestamp = dateFormatter.string(from: Date(timeIntervalSince1970: 1658936282257))
                                    let secsSince1970: Double = historicalMessage.published.timetokenDate.timeIntervalSince1970
                                    newMsg.humanReadableTime = dateFormatter.string(from: Date(timeIntervalSince1970: secsSince1970))
                                    //newMsg.timestamp = String(historicalMessage.published)
                                    viewModel.messages.append(newMsg)
                                }
                            }
                        case let .failure(error):
                            print("Failed to retrieve history: \(error.localizedDescription)")
                        }
 
                    }

                }
            case let .presenceChanged(presence):
              print("Presence Received: \(presence)")
                //  For this logic to work, make sure you have presence deltas enabled on your key
                for action in presence.actions {
                    switch action {
                    case let .join(uuids):
                        print(uuids)
                        uuids.forEach { deviceId in
                            addMember(deviceId: deviceId)
                        }
                        break;
                    case let .leave(uuids):
                        print(uuids)
                        uuids.forEach { deviceId in
                            removeMember(deviceId: deviceId)
                        }
                        break;
                    case .timeout(_):
                        print("Presence - timeout")
                        break;
                    case let .stateChange(uuid, state):
                        print("\(uuid) changed their presence state to \(state) at \(presence.timetoken)")
                    }
                }
            case let .subscribeError(error):
              print("Subscription Error \(error)")
            default:
              break
            }
        }
        if (viewModel.listener != nil) {
            viewModel.pubnub?.add(viewModel.listener!)
        }
            
        viewModel.objectsListener = SubscriptionListener()
        viewModel.objectsListener?.didReceiveObjectMetadataEvent = { event in
            switch event {
            case .setUUID(let metadata):
                let changedId: String = metadata.metadataId;
                for change in metadata.changes {
                    switch change {
                    case let .stringOptional(_, value):
                        let changedValue: String = value?.stringOptional ?? changedId
                        replaceMemberName (
                            deviceId: changedId, newName: changedValue
                        )
                    case .customOptional(_, _):
                        //  No action
                        break;
                    }
                }
                break;
            default:
                break
            }
        }
        if (viewModel.objectsListener != nil) {
            viewModel.pubnub?.add(viewModel.objectsListener!)
        }
        
        addMember(deviceId: viewModel.deviceId ?? "defaultId")
        
        
        viewModel.pubnub?.hereNow(on: [groupChatChannel], includeUUIDs: true) {result in
            switch result {
            case let .success(presenceByChannel):
                if let myChannelPresence = presenceByChannel[groupChatChannel] {
                    myChannelPresence.occupants.forEach { member in
                        addMember(deviceId: member)
                    }
                }
            case let .failure(error):
                print("Failed hereNow Response: \(error)")
            }
            
            
        }
        
    }

    func applicationSentToBackground(viewModel: ChatViewModel)
    {
        viewModel.pubnub?.unsubscribe(from: [groupChatChannel]);
        
        viewModel.listener?.cancel()
        viewModel.objectsListener?.cancel()
    }
    
    func initializePubNub(viewModel: ChatViewModel)
    {
        let publish_key = PUBNUB_PUBLISH_KEY
        let subscribe_key = PUBNUB_SUBSCRIBE_KEY
        if (publish_key == "REPLACE WITH YOUR PUBNUB PUBLISH KEY" ||
            subscribe_key == "REPLACE WITH YOUR PUBNUB SUBSCRIBE KEY")
        {
            viewModel.heading = "MISSING KEYS"
            return;
        }
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "defaultId"
        let config = PubNubConfiguration (
            publishKey: publish_key, subscribeKey: subscribe_key, userId: deviceId
        )
        
        viewModel.deviceId = deviceId
        viewModel.channel = groupChatChannel
        viewModel.pubnub = PubNub(configuration: config)
        viewModel.friendlyName = deviceId
        //let pubnub = PubNub(configuration: config)

        

    }
    
    func addMember(deviceId: String)
    {
        if (!viewModel.groupMemberDeviceIds.contains(deviceId)) {
            viewModel.groupMemberDeviceIds.insert(_: deviceId, at: 0)
        }
        lookupMemberName(deviceId: deviceId)
    }
    
    func removeMember(deviceId: String)
    {
        if (viewModel.groupMemberDeviceIds.contains(deviceId)) {
            if let index = viewModel.groupMemberDeviceIds.firstIndex(of: deviceId) {
                viewModel.groupMemberDeviceIds.remove(at: index)
            }
        }

    }
    
    func lookupMemberName(deviceId: String)
    {
        let result = viewModel.memberNames.contains {$0.key == deviceId}
        if result {
            //  We already know the member name, take no action
        }
        else{
            //  Resolve the friendly name of the deviceId
            viewModel.pubnub?.fetch(uuid: deviceId) { result in
                switch result {
                case let .success(uuidMetadata):
                    //  Add the user's name to the memberNames dictionary (part of the viewModel, so
                    //  the UI will update accordingly)
                    viewModel.memberNames[deviceId] = uuidMetadata.name
                    //  Set our own friendly name (stored separately to make the UI logic easier)
                    if (deviceId == viewModel.deviceId) {
                        viewModel.friendlyName = uuidMetadata.name ?? "default name"
                    }
                case let .failure(_):
                    print("Could not find friendly name for device: " + deviceId)
                }
            }
        }
    }
    
    func replaceMemberName(deviceId: String, newName: String)
    {
        viewModel.memberNames[deviceId] = newName;
    }
        
}








struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

