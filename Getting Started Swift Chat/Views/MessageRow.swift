//
//  MessageRow.swift
//  Getting Started Swift Chat
//
//  Created by Darryn Campbell on 26/07/2022.
//

import SwiftUI

struct MessageRow: View {
    var message: Message
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        HStack {
            VStack (alignment: .leading){
                Text(self.viewModel.resolveFriendlyName(deviceId: message.senderDeviceId ))
                Text(message.message).fontWeight(.bold)
                Text(message.humanReadableTime).font(.footnote).frame(maxWidth: .infinity, alignment: .trailing).foregroundColor(Color.gray)
            }
            .frame(minWidth: 0,
                   maxWidth: .infinity)
            Spacer()
        }
    }
    
}


/*
struct MessageRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MessageRow(message: messages[0])
            MessageRow(message: messages[1])
        }
        .previewLayout(.fixed(width: 300, height: 70))

    }
}
*/
