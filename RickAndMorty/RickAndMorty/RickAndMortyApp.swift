//
//  RickAndMortyApp.swift
//  RickAndMorty
//
//  Created by Pablo Blanco Peris on 18/11/2026.
//

import Presentation
import SwiftUI

@main
@MainActor
struct RickAndMortyApp: App {
    var body: some Scene {
        WindowGroup {
            CharactersView()
        }
    }
}
