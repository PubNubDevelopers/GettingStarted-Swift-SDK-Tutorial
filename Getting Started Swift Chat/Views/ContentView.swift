//
//  ContentView.swift
//  Getting Started Swift Chat
//
//  Created by Darryn Campbell on 26/07/2022.
//

import SwiftUI
import PubNub

struct ContentView: View {
    @ObservedObject var viewModel: ChatViewModel = ChatViewModel()
    @Environment(\.scenePhase) var scenePhase
    
    //  This application hardcodes a single channel name for simplicity.
    //  Typoically you would use separate channels for each type of conversation
    //  e.g. Each 1:1 chat woul dhave its own channel, named appropriately
    let groupChatChannel: String = "group_chat"
    
    //  Lifecycle of the application will create and configure the PubNub object when the
    //  application is first launched.  When the application goes to the background,
    //  the channel is unsubscribed from, until it returns to the foreground.
    //  This demonstrates presence.
    var body: some View {
        VStack (alignment: .leading, spacing: 0) {
            Header(viewModel: viewModel)
            MessageList(viewModel: viewModel)
            MessageInput(viewModel: viewModel)
            Spacer()
        }
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
        
        //  Applications receive various types of information from PubNub through a 'listener'
        //  This application dynamically registers an listener when it is in the foreground
        viewModel.listener = SubscriptionListener()
        viewModel.listener?.didReceiveSubscription = {
            event in
            switch event {
            case let .messageReceived(message):
                
                let messageText: String = message.payload.stringOptional ?? ""
                let sender: String = message.publisher ?? ""
                
                var newMsg = Message(message: messageText, senderDeviceId: sender, timetoken: String(message.published))
                let dateFormatter = DateFormatter()
                dateFormatter.timeStyle = DateFormatter.Style.medium
                dateFormatter.dateStyle = DateFormatter.Style.medium
                dateFormatter.timeZone = .current
                let secsSince1970: Double = message.published.timetokenDate.timeIntervalSince1970
                newMsg.humanReadableTime = dateFormatter.string(from: Date(timeIntervalSince1970: secsSince1970))
                
                viewModel.messages.append(newMsg)
                
                //  Status events are commonly used to notify the application that a previous PubNub call has succeeded
                //  Not all PubNub calls return their status in this manner but is used in this app to ensure
                //  we are connected before we set the app membership.
            case let .connectionStatusChanged(status):
                if (status == ConnectionStatus.connected)
                {
                    //  In order to receive object UUID events (didReceiveObjectMetaDataEvent) it is
                    //  required to set our membership using the Object API.
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
                    
                    //  When the application is first loaded, it is common to load any recent chat messages
                    //  so the user can get caught up with conversations they missed.
                    //  Every application will handle this differently but here we just load the most recent
                    //  messages
                    viewModel.pubnub?.fetchMessageHistory(for: [groupChatChannel], includeMeta: true, includeUUID: true, page: PubNubBoundedPageBase(limit: 8)) { result in
                        switch result {
                        case let .success(response):
                            if let myChannelMessages = response.messagesByChannel[groupChatChannel] {
                                myChannelMessages.forEach { historicalMessage in
                                    //  Recreate the message and add it to the viewModel for display.
                                    var newMsg = Message()
                                    newMsg.message = historicalMessage.payload.stringOptional ?? "Not found"
                                    newMsg.senderDeviceId = historicalMessage.publisher?.stringOptional ?? "Unknown"
                                    newMsg.timetoken = String(historicalMessage.published)
                                    let dateFormatter = DateFormatter()
                                    dateFormatter.timeStyle = DateFormatter.Style.medium
                                    dateFormatter.dateStyle = DateFormatter.Style.medium
                                    dateFormatter.timeZone = .current
                                    let secsSince1970: Double = historicalMessage.published.timetokenDate.timeIntervalSince1970
                                    newMsg.humanReadableTime = dateFormatter.string(from: Date(timeIntervalSince1970: secsSince1970))
                                    viewModel.messages.append(newMsg)
                                    
                                    lookupMemberName(deviceId: newMsg.senderDeviceId)
                                }
                            }
                        case let .failure(error):
                            print("Failed to retrieve history: \(error.localizedDescription)")
                        }
                    }
                }
                
                //  Be notified that a 'presence' event has occurred.  I.e. somebody has left or joined
                //  the channel.  This is similar to the earlier hereNow call but this API will only be
                //  invoked when presence information changes, meaning you do NOT have to call hereNow
                //  periodically.  More info: https://www.pubnub.com/docs/sdks/swift/api-reference/presence
            case let .presenceChanged(presence):
                //  A note about ANNOUNCE_MAX:
                //  There is a server setting, ANNOUNCE_MAX, that you can configure on your keyset.  This
                //  defaults to 20 users and after this number of attendees join each channel, presence
                //  events are only sent periodically every x seconds, where x is also configured on the keyset.
                //  More info: https://www.pubnub.com/docs/presence/presence-events#interval-mode
                //  Since this application needs to know which UUIDs have joined or left since the last update,
                //  YOU NEED TO SET 'Presence Deltas' to true on the keyset, if you have more than ANNOUNCE_MAX
                //  users, using this app.
                for action in presence.actions {
                    switch action {
                    case let .join(uuids):
                        uuids.forEach { deviceId in
                            addMember(deviceId: deviceId)
                        }
                        break;
                    case let .leave(uuids):
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
        
        //  Having created the listener object, add it to the PubNub object and remember it
        //  so it can be removed when the application goes to the background
        
        if (viewModel.listener != nil) {
            viewModel.pubnub?.add(viewModel.listener!)
        }
        
        //  Whenever Object meta data is changed, an Object event is received.
        //  See: https://www.pubnub.com/docs/chat/sdks/users/setup
        //  Use this to be notified when other users change their friendly names
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
        
        //  Having created the listener object, add it to the PubNub object and remember it
        //  so it can be removed when the application goes to the background
        if (viewModel.objectsListener != nil) {
            viewModel.pubnub?.add(viewModel.objectsListener!)
        }
        
        //  Determine who is currently chatting on the channel.  I use an Array in the viewModel
        //  to present this information on the UI, managed through a couple of addMember and
        //  removeMember methods.
        //  I am definitely here(!)
        addMember(deviceId: viewModel.deviceId ?? "defaultId")
        
        //  PubNub has an API to determine who is in the room.  Use this call sparingly since
        //  you are only ever likely to need to know EVERYONE in the room when the UI is first
        // created.
        viewModel.pubnub?.hereNow(on: [groupChatChannel], includeUUIDs: true) {result in
            switch result {
            case let .success(presenceByChannel):
                if let myChannelPresence = presenceByChannel[groupChatChannel] {
                    //  The API will return an array of occupants in the channel, defined by
                    //  their ID.  This application will need to look up the friendly name
                    //  defined for each of these IDs (later)
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
        //  This getting stated application is set up to unsubscribe from all channels
        //  when the app goes into the background.  This is good to show the principles
        //  of presence but you don't need to do this in a production app if it
        //  does not fit your use case.
        viewModel.pubnub?.unsubscribe(from: [groupChatChannel]);
        viewModel.listener?.cancel()
        viewModel.objectsListener?.cancel()
    }
    
    func initializePubNub(viewModel: ChatViewModel)
    {
        let publish_key = PUBNUB_PUBLISH_KEY
        let subscribe_key = PUBNUB_SUBSCRIBE_KEY
        
        //  You need to specify a Publish and Subscribe key when configuring PubNub on the device.
        //  This application will load them from a separate constants file (See ReadMe for
        //  information on obtaining keys)
        if (publish_key == "REPLACE WITH YOUR PUBNUB PUBLISH KEY" ||
            subscribe_key == "REPLACE WITH YOUR PUBNUB SUBSCRIBE KEY")
        {
            viewModel.heading = "MISSING KEYS"
            return;
        }
        
        //  Create a device-specific DeviceId to represent this device and user, so PubNub
        //  knows who is connecting.
        //  More info: https://support.pubnub.com/hc/en-us/articles/360051496532-How-do-I-set-the-UUID-
        //  All iOS IDs are user-resettable but are still appropriate for use here.
        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "defaultId"
        
        //  Create a PubNub configuration and instantiate the PubNub object, used to
        //  communicate with PubNub
        let config = PubNubConfiguration (
            publishKey: publish_key, subscribeKey: subscribe_key, userId: deviceId
        )
        
        //  Application state
        viewModel.pubnub = PubNub(configuration: config)
        viewModel.deviceId = deviceId
        viewModel.channel = groupChatChannel
        viewModel.friendlyName = deviceId
        
    }
    
    //  A DeviceID is present in the chat (as determined by either hereNow or the presence
    //  event).  Update our chat member list.
    func addMember(deviceId: String)
    {
        if (!viewModel.groupMemberDeviceIds.contains(deviceId)) {
            viewModel.groupMemberDeviceIds.insert(_: deviceId, at: 0)
        }
        lookupMemberName(deviceId: deviceId)
    }
    
    //  A DeviceID is absent from the chat (as determined by either hereNow or the presence
    //  event).  Update our chat member list.
    func removeMember(deviceId: String)
    {
        if (viewModel.groupMemberDeviceIds.contains(deviceId)) {
            if let index = viewModel.groupMemberDeviceIds.firstIndex(of: deviceId) {
                viewModel.groupMemberDeviceIds.remove(at: index)
            }
        }
        
    }
    
    //  The 'master record' for each device's friendly name is stored in PubNub Object storage.
    //  This avoids the application defining its own server storage or trying to keep track of
    //  all friendly names on every device.  Since PubNub Objects understand the concept of a
    //  user name (along with other common fields like email and profileUrl), it makes the
    //  process straight forward.
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
                case .failure(_):
                    print("Could not find friendly name for device: " + deviceId)
                }
            }
        }
    }
    
    //  Update the Dictionary of DeviceId --> friendly name mappings.
    //  Used for when names CHANGE
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

