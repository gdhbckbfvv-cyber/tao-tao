//
//  ContentView.swift
//  EarthLord
//
//  Created by Zhuanz密码0000 on 12/24/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")

            Spacer()
                .frame(height: 40)

            Text("Developed by Claude")
                .font(.headline)
                .foregroundColor(.blue)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
