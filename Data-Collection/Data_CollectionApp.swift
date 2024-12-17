//
//  Data_CollectionApp.swift
//  Data-Collection
//
//  Created by Shubham Attri on 16/12/24.
//

import SwiftUI
import SwiftData

@main
struct Data_CollectionApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            SensorData.self  // Add SensorData to the schema
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
