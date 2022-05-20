//
//  ProfileViewModel.swift
//  Messenger
//
//  Created by Nadheer on 20/05/2022.
//

import Foundation

enum ProfileViewModelType {
    case info, logout
}

struct ProfileViewModel {
    let viewModelType: ProfileViewModelType
    let title: String
    let handler: (() -> Void)?
}
