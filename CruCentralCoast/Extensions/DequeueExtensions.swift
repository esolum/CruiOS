//
//  DequeueExtensions.swift
//  CruCentralCoast
//
//  Created by Michael Cantrell on 3/29/18.
//  Copyright © 2018 Landon Gerrits. All rights reserved.
//

import UIKit

public extension UICollectionView {
    func registerCell<T: UICollectionViewCell>(_ cellType: T.Type){
        self.register(UINib(nibName: String(describing: cellType.self), bundle: nil), forCellWithReuseIdentifier: String(describing: cellType.self))
    }
    
    func registerClass<T: UICollectionViewCell>(_ cellType: T.Type){
        self.register(cellType.self, forCellWithReuseIdentifier: String(describing: cellType.self))
    }
    
    func dequeueCell<T: UICollectionViewCell>(_ cellType: T.Type, indexPath: IndexPath) -> T {
        let reuseID = String(describing: T.self)
        guard let cell = self.dequeueReusableCell(withReuseIdentifier: reuseID, for: indexPath) as? T else {
            fatalError("The dequeued cell is not an instance of \(reuseID).")
        }
        return cell
    }
}

public extension UITableView {
    func registerCell<T: UITableViewCell>(_ cellType: T.Type){
        self.register(UINib(nibName: String(describing: cellType.self), bundle: nil), forCellReuseIdentifier: String(describing: cellType.self))
    }
    
    func registerClass<T: UITableViewCell>(_ cellType: T.Type){
        self.register(cellType.self, forCellReuseIdentifier: String(describing: cellType.self))
    }
    
    func dequeueCell<T: UITableViewCell>(_ cellType: T.Type, indexPath: IndexPath) -> T {
        let reuseID = String(describing: T.self)
        guard let cell = self.dequeueReusableCell(withIdentifier: reuseID, for: indexPath) as? T else {
            fatalError("The dequeued cell is not an instance of \(reuseID).")
        }
        return cell
    }
}
