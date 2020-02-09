//
//  PostController.swift
//  Continuum
//
//  Created by Maxwell Poffenbarger on 2/4/20.
//  Copyright © 2020 Max Poff. All rights reserved.
//

import UIKit
import CloudKit

class PostController {
    
    //MARK: - Properties
    static let shared = PostController()
    var posts: [Post] = []
    private init() {
        subscribeToNewPosts(completion: nil)
    }
    
    //MARK: - CK Methods (Create)
    func addComment(text: String, post: Post, completion: @escaping (Comment?) -> Void) {
        
        let comment = Comment(text: text, post: post)
        
        post.comments.append(comment)
        
        let record = CKRecord(comment: comment)
        
        CKContainer.default().publicCloudDatabase.save(record) { (record, error) in
            
            if let error = error {
                print("Error in \(#function) : \(error.localizedDescription) \n---\n \(error)" )
                return completion(nil)
            }
            
            guard let record = record else { return completion(nil) }
            
            let comment = Comment(ckRecord: record, post: post)
            
            self.incrementCommentCount(for: post, completion: nil)
            
            completion(comment)
        }
    }
    
    func createPostWith(photo: UIImage, caption: String, completion: @escaping (Post?) -> Void) {
        
        let post = Post(photo: photo, caption: caption)
        
        self.posts.append(post)
        
        let record = CKRecord(post: post)
        
        CKContainer.default().publicCloudDatabase.save(record) { (record, error) in
            
            if let error = error{
                print("Error in \(#function) : \(error.localizedDescription) \n---\n \(error)" )
                return completion(nil)
            }
            
            guard let record = record,
                let post = Post(ckRecord: record)  else { return completion(nil) }
            
            completion(post)
        }
    }
    
    //MARK: - CK Methods (Read)
    func fetchPosts(completion: @escaping ([Post]?) -> Void){
        
        let predicate = NSPredicate(value: true)
        
        let query = CKQuery(recordType: PostConstants.typeKey, predicate: predicate)
        
        CKContainer.default().publicCloudDatabase.perform(query, inZoneWith: nil) { (records, error) in
            
            if let error = error{
                print("Error in \(#function) : \(error.localizedDescription) \n---\n \(error)" )
                return completion(nil)
            }
            guard let records = records else { return completion(nil) }
            
            let posts = records.compactMap{ Post(ckRecord: $0) }
            
            self.posts = posts
            
            completion(posts)
        }
    }
    
    func fetchComments(for post: Post, completion: @escaping ([Comment]?) -> Void){
        
        let postRefence = post.recordID
        
        let predicate = NSPredicate(format: "%K == %@", CommentConstants.postReferenceKey, postRefence)
        
        let commentIDs = post.comments.compactMap({$0.recordID})
        
        let predicate2 = NSPredicate(format: "NOT(recordID IN %@)", commentIDs)
        
        let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [predicate, predicate2])
        
        let query = CKQuery(recordType: "Comment", predicate: compoundPredicate)
        
        CKContainer.default().publicCloudDatabase.perform(query, inZoneWith: nil) { (records, error) in
            
            if let error = error {
                print("Error fetching comments \(#function) \(error) \(error.localizedDescription)")
                return completion(nil)
            }
            guard let records = records else { completion(nil); return }
            
            let comments = records.compactMap{ Comment(ckRecord: $0, post: post) }
            
            post.comments.append(contentsOf: comments)
            
            completion(comments)
        }
    }
    
    //MARK: - CK Methods (Update)
    func incrementCommentCount(for post: Post, completion: ((Bool)-> Void)?){
        
        post.commentCount += 1
        
        let modifyOperation = CKModifyRecordsOperation(recordsToSave: [CKRecord(post: post)], recordIDsToDelete: nil)
        
        modifyOperation.savePolicy = .changedKeys
        
        modifyOperation.modifyRecordsCompletionBlock = { (records, _, error) in
            
            if let error = error{
                print("Error in \(#function) : \(error.localizedDescription) \n---\n \(error)" )
                completion?(false)
                return
            } else {
                completion?(true)
            }
        }
        CKContainer.default().publicCloudDatabase.add(modifyOperation)
    }
    
    //MARK: - CK Methods (Subscriptions)
    func subscribeToNewPosts(completion: ((Bool, Error?) -> Void)?){
        
        let predicate = NSPredicate(value: true)
        
        let subscription = CKQuerySubscription(recordType: "Post", predicate: predicate, subscriptionID: "AllPosts", options: CKQuerySubscription.Options.firesOnRecordCreation)
        
        let notifcationInfo = CKSubscription.NotificationInfo()
        notifcationInfo.alertBody = "New post added to Continuum"
        
        notifcationInfo.shouldBadge = true
        notifcationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notifcationInfo
        
        CKContainer.default().publicCloudDatabase.save(subscription) { (subscription, error) in
            
            if let error = error {
                print("There was an error in \(#function) ; \(error)  ; \(error.localizedDescription)")
                completion?(false, error)
                return
            } else {
                completion?(true, nil)
            }
        }
    }
    
    func addSubscritptionTo(commentsForPost post: Post, completion: ((Bool, Error?) -> ())?){
        
        let postRecordID = post.recordID
        
        let predicate = NSPredicate(format: "%K = %@", CommentConstants.postReferenceKey, postRecordID)
        
        let subscription = CKQuerySubscription(recordType: "Comment", predicate: predicate, subscriptionID: post.recordID.recordName, options: CKQuerySubscription.Options.firesOnRecordCreation)
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.alertBody = "A new comment was added to a post that you follow"
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.desiredKeys = nil
        subscription.notificationInfo = notificationInfo
        
        CKContainer.default().publicCloudDatabase.save(subscription) { (_, error) in
            
            if let error = error {
                print("There was an error in \(#function) ; \(error)  ; \(error.localizedDescription)")
                completion?(false, error)
                return
            } else{
                completion?(true, nil)
            }
        }
    }
    
    func removeSubscriptionTo(commentsForPost post: Post, completion: ((Bool) -> ())?) {
        
        let subscriptionID = post.recordID.recordName
        
        CKContainer.default().publicCloudDatabase.delete(withSubscriptionID: subscriptionID) { (_, error) in
            
            if let error = error {
                print("There was an error in \(#function) ; \(error)  ; \(error.localizedDescription)")
                completion?(false)
                return
            } else {
                print("Subscription deleted")
                completion?(true)
            }
        }
    }
    
    func checkForSubscription(to post: Post, completion: ((Bool) -> ())?) {
        
        let subscriptionID = post.recordID.recordName
        
        CKContainer.default().publicCloudDatabase.fetch(withSubscriptionID: subscriptionID) { (subscription, error) in
            
            if let error = error {
                print("There was an error in \(#function) ; \(error)  ; \(error.localizedDescription)")
                completion?(false)
                return
            }
            
            if subscription != nil {
                completion?(true)
            } else {
                completion?(false)
            }
        }
    }
    
    func toggleSubscriptionTo(commentsForPost post: Post, completion: ((Bool, Error?) -> ())?){
        
        checkForSubscription(to: post) { (isSubscribed) in
            
            if isSubscribed{
                self.removeSubscriptionTo(commentsForPost: post, completion: { (success) in
                    if success {
                        print("Successfully removed the subscription to the post with caption: \(post.caption)")
                        completion?(true, nil)
                    } else {
                        print("There was an error removing the subscription to the post with caption: \(post.caption)")
                        completion?(false, nil)
                    }
                })
            } else {
                self.addSubscritptionTo(commentsForPost: post, completion: { (success, error) in
                    if let error = error {
                        print("There was an error in \(#function) ; \(error)  ; \(error.localizedDescription)")
                        completion?(false, error)
                        return
                    }
                    if success {
                        print("Successfully subscribed to the post with caption: \(post.caption)")
                        completion?(true, nil)
                    } else {
                        print("There was an error subscribing to the post with caption: \(post.caption)")
                        completion?(false, nil)
                    }
                })
            }
        }
    }
}
