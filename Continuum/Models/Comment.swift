//
//  Comment.swift
//  Continuum
//
//  Created by Maxwell Poffenbarger on 2/4/20.
//  Copyright © 2020 Max Poff. All rights reserved.
//

import Foundation
import CloudKit

//MARK: - String Constants
struct CommentConstants {
    
    static let recordType = "Comment"
    static let textKey = "text"
    static let timestampKey = "timestamp"
    static let postReferenceKey = "post"
}//End of struct

//MARK: - Class Model
class Comment {
    
    let text: String
    let timestamp: Date
    weak var post: Post?
    let recordID: CKRecord.ID
    
    var postReference: CKRecord.Reference? {
        guard let post = post else { return nil }
        return CKRecord.Reference(recordID: post.recordID, action: .deleteSelf)
    }
    
    init(text: String, post: Post, timestamp: Date = Date(), recordID: CKRecord.ID = CKRecord.ID(recordName: UUID().uuidString)) {
        self.text = text
        self.post = post
        self.timestamp = timestamp
        self.recordID = recordID
    }
    
    //MARK: - TURN THIS INTO AN EXTENSION
    convenience init?(ckRecord: CKRecord, post: Post){
        guard let text = ckRecord[CommentConstants.textKey] as? String,
            let timestamp = ckRecord[CommentConstants.timestampKey] as? Date else { return nil }
        self.init(text: text, post: post, timestamp: timestamp, recordID: ckRecord.recordID)
    }
}//End of class

//MARK: - Extensions
extension CKRecord {
    
    convenience init(comment: Comment) {
        
        self.init(recordType: CommentConstants.recordType, recordID: comment.recordID)
        
        self.setValuesForKeys([CommentConstants.postReferenceKey : comment.postReference,
                               CommentConstants.textKey : comment.text,
                               CommentConstants.timestampKey : comment.timestamp])
    }
}//End of extension

extension Comment: SearchableRecord {
    func matches(searchTerm: String) -> Bool {
        return text.lowercased().contains(searchTerm.lowercased())
    }
}//End of extension
