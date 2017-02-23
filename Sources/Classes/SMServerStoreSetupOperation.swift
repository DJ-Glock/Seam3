//    SMServerStoreSetupOperation.swift
//
//    The MIT License (MIT)
//
//    Copyright (c) 2016 Paul Wilkinson ( https://github.com/paulw11 )
//
//    Based on work by Nofel Mahmood
//
//    Portions copyright (c) 2015 Nofel Mahmood ( https://twitter.com/NofelMahmood )
//
//    Permission is hereby granted, free of charge, to any person obtaining a copy
//    of this software and associated documentation files (the "Software"), to deal
//    in the Software without restriction, including without limitation the rights
//    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//    copies of the Software, and to permit persons to whom the Software is
//    furnished to do so, subject to the following conditions:
//
//    The above copyright notice and this permission notice shall be included in all
//    copies or substantial portions of the Software.
//
//    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//    SOFTWARE.


import Foundation
import CloudKit



class SMServerStoreSetupOperation:Operation {
    
    var database:CKDatabase?
    var setupOperationCompletionBlock:((_ customZoneCreated:Bool,_ customZoneSubscriptionCreated:Bool)->Void)?
    
    init(cloudDatabase:CKDatabase?) {
        self.database = cloudDatabase
        super.init()
    }
    
    override func main() {
        let operationQueue = OperationQueue()
        let zone = CKRecordZone(zoneName: SMStore.SMStoreCloudStoreCustomZoneName)
        var error: NSError?
        let modifyRecordZonesOperation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: nil)
        modifyRecordZonesOperation.database = self.database
        modifyRecordZonesOperation.modifyRecordZonesCompletionBlock = ({(savedRecordZones, deletedRecordZonesIDs, operationError) -> Void in
            error = operationError as NSError?
            let customZoneWasCreated:AnyObject? = UserDefaults.standard.object(forKey: SMStore.SMStoreCloudStoreCustomZoneName) as AnyObject?
            let customZoneSubscriptionWasCreated:AnyObject? = UserDefaults.standard.object(forKey: SMStore.SMStoreCloudStoreSubscriptionName) as AnyObject?
            if ((operationError == nil || customZoneWasCreated != nil) && customZoneSubscriptionWasCreated == nil) {
                UserDefaults.standard.set(true, forKey: SMStore.SMStoreCloudStoreCustomZoneName)
                let recordZoneID = CKRecordZoneID.smCloudStoreCustomZoneID()
                let subscription = CKSubscription(zoneID: recordZoneID, subscriptionID: SMStore.SMStoreCloudStoreSubscriptionName, options: CKSubscriptionOptions(rawValue: 0))
                let subscriptionNotificationInfo = CKNotificationInfo()
                #if os(iOS) || os(macOS)
                    subscriptionNotificationInfo.alertBody = ""
                #endif
                subscriptionNotificationInfo.shouldSendContentAvailable = true
                subscription.notificationInfo = subscriptionNotificationInfo
                if #available(iOS 9.0, tvOS 10.0, *) {
                    subscriptionNotificationInfo.shouldBadge = false
                }
                let subscriptionsOperation = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
                subscriptionsOperation.database = self.database
                subscriptionsOperation.modifySubscriptionsCompletionBlock=({ (modified,created,operationError) -> Void in
                    if operationError == nil {
                        UserDefaults.standard.set(true, forKey: SMStore.SMStoreCloudStoreSubscriptionName)
                    }
                    error = operationError as NSError?
                })
                operationQueue.addOperation(subscriptionsOperation)
            }
        })
        operationQueue.addOperation(modifyRecordZonesOperation)
        operationQueue.waitUntilAllOperationsAreFinished()
        if self.setupOperationCompletionBlock != nil {
            if error == nil {
                self.setupOperationCompletionBlock!(true, true)
            } else {
                if UserDefaults.standard.object(forKey: SMStore.SMStoreCloudStoreCustomZoneName) == nil {
                    self.setupOperationCompletionBlock!(false, false)
                } else {
                    self.setupOperationCompletionBlock!(true, false)
                }
            }
        }
    }
}
