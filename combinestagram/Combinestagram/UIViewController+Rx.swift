//
//  UIViewController+Rx.swift
//  Combinestagram
//
//  Created by Soojung Shin on 2020/02/15.
//  Copyright © 2020 Underplot ltd. All rights reserved.
//

import UIKit
import RxSwift

extension UIViewController {
  func alert(title: String, text: String?) -> Completable {
    return Completable.create { [weak self] completable in
      
      let alertVC = UIAlertController(title: title, message: text, preferredStyle: .alert)
      alertVC.addAction(UIAlertAction(title: "Close", style: .default, handler: { _ in
        completable(.completed)
      }))
      
      self?.present(alertVC, animated: true, completion: nil)
      
      return Disposables.create {
        //dispose 될 때 수행될 작업 지정
        self?.dismiss(animated: true, completion: nil)
      }
    }
  }
}

