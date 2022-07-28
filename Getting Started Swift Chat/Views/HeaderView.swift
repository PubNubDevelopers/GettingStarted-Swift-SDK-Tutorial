//
//  HeaderView.swift
//  Getting Started Swift Chat
//
//  Created by Darryn Campbell on 28/07/2022.
//

import SwiftUI
import PubNub
import WrappingStack

struct Header: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var displayMembers: String = ""
    //@State private var friendlyName: String = ""
    @State private var friendlyNameIsEditable: Bool = false
    @State private var buttonValue: String = "Edit"
    @State private var friendlyNameColor: Color = Color.white
    @State private var friendlyNameBackground: Color = .clear
    @FocusState private var messageIsFocused: Bool

    var body: some View {
                            
                        HStack () {
                            VStack(alignment: .leading) {
                               Text(viewModel.heading)
                                   .font(.title)
                                   .fontWeight(.bold)
                                   .foregroundColor(Color.white)
                               
                                Text("Members: ")
                                    .fontWeight(.bold)
                                    .foregroundColor(Color.white)

                                WrappingHStack (id: \.self, alignment: .topLeading, horizontalSpacing: 10, verticalSpacing: 0) {
                                    ForEach(viewModel.groupMemberDeviceIds, id: \.self) { deviceId in
                                        Text(viewModel.memberNames[deviceId] ?? deviceId)
                                            .font(.subheadline)
                                            .foregroundColor(Color.white)
                                    }
                                }

                                HStack {
                                    Text("Friendly Name: ").foregroundColor(Color.white).fontWeight(.bold)
                                    TextField("NOT YET DEFINED", text: $viewModel.friendlyName)
                                        .disabled(!friendlyNameIsEditable)
                                        .foregroundColor(friendlyNameColor)
                                        .background(friendlyNameBackground)
                                        .focused($messageIsFocused)
                                    Button(buttonValue) {
                                        messageIsFocused = false;
                                        if (buttonValue == "Edit") {
                                            buttonValue = "Save"
                                            friendlyNameColor = .black
                                            friendlyNameBackground = .white
                                            friendlyNameIsEditable = true
                                        }
                                        else {
                                            //  'Save' was pressed
                                            buttonValue = "Edit"
                                            friendlyNameColor = .white
                                            friendlyNameBackground = .clear
                                            friendlyNameIsEditable = false
                                            
                                            //  todo check length is > 0 for name
                                            if(viewModel.friendlyName == "")
                                            {
                                                viewModel.friendlyName = "default"
                                            }

                                            //  Publish message to PubNub
                                            let uuidMetaData = PubNubUUIDMetadataBase(
                                                metadataId: viewModel.deviceId ?? "defaultValue",
                                                name: viewModel.friendlyName
                                            )
                                            viewModel.pubnub?.set(uuid: uuidMetaData) { result in
                                                switch result {
                                                case let .success(uuidMetadata):
                                                    print("Metadata successfully set \(uuidMetaData)")
                                                case let .failure(error):
                                                    print("Create UUID meta data failed with error: \(error)")
                                                }
                                            }
                                        }
                                        

                                    }.padding(3).background(RoundedRectangle(cornerRadius: 8).fill(Color.white))
                                }
                           }
                           .frame(
                            minWidth: 0,
                            maxWidth: .infinity,
                            alignment: .topLeading)
                           .padding(.leading, 25)
                           .padding(.trailing, 25)
                           .padding(.top, 0)
                           .padding(.bottom, 10)
                       }
                       .background(Color("PubNubDarkGreen"))
                       .onAppear() {
                           //friendlyName = viewModel.resolveFriendlyName(deviceId: self.viewModel.deviceId ?? "defaultId")
                           
                       }

                   }


            
}
