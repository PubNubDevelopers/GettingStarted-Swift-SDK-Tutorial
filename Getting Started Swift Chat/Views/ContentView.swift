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
        //  TUTORIAL: STEP 2B CODE GOES HERE (1/2)
        
        //  TUTORIAL: STEP 2D CODE IS ALREADY PRESENT HERE AS CONTAINS GLUE CODE
        
        viewModel.listener = SubscriptionListener()
        viewModel.listener?.didReceiveSubscription = {
            event in
            switch event {
            case let .messageReceived(message):

                //  TUTORIAL: STEP 2E CODE GOES HERE
                
                break;
                
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
                    
                    //  TUTORIAL: STEP 2G CODE GOES HERE
                    
                }
                
                //  Be notified that a 'presence' event has occurred.  I.e. somebody has left or joined
                //  the channel.  This is similar to the earlier hereNow call but this API will only be
                //  invoked when presence information changes, meaning you do NOT have to call hereNow
                //  periodically.  More info: https://www.pubnub.com/docs/sdks/swift/api-reference/presence
            case let .presenceChanged(presence):
                
                //  TUTORIAL: STEP 2F CODE GOES HERE (1/2)
                break;
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

                //  TUTORIAL: STEP 2I CODE GOES HERE (2/2)
                
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
        
        //  TUTORIAL: STEP 2F CODE GOES HERE (2/2)
        
    }
    
    func applicationSentToBackground(viewModel: ChatViewModel)
    {
        //  This getting stated application is set up to unsubscribe from all channels
        //  when the app goes into the background.  This is good to show the principles
        //  of presence but you don't need to do this in a production app if it
        //  does not fit your use case.

        //  TUTORIAL: STEP 2B CODE GOES HERE (2/2)
        
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
        
        //  TUTORIAL: STEP 2A CODE GOES HERE
        
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

            //  TUTORIAL: STEP 2I CODE GOES HERE (1/2)
            
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

