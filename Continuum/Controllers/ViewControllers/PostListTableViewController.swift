//
//  PostListTableViewController.swift
//  Continuum
//
//  Created by Maxwell Poffenbarger on 2/4/20.
//  Copyright © 2020 Max Poff. All rights reserved.
//

import UIKit

class PostListTableViewController: UITableViewController {
    
    //MARK: - Outlets
    @IBOutlet weak var postSearchBar: UISearchBar!
    
    //MARK: - Properties
    var resultsArray: [SearchableRecord] = []
    
    var isSearching = false
    
    var dataSource: [SearchableRecord] {
        return isSearching ? resultsArray : PostController.sharedInstance.posts
    }
    
    //MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        postSearchBar.delegate = self
        performFullSync(completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        DispatchQueue.main.async {
            self.resultsArray = PostController.sharedInstance.posts
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Table View Data Source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "postCell", for: indexPath) as? PostTableViewCell else {return UITableViewCell()}
        
        let post = dataSource[indexPath.row] as? Post
        
        cell.post = post
        
        return cell
    }
    
    //MARK: - Class Methods
    func performFullSync(completion:((Bool) ->Void)?){
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        PostController.sharedInstance.fetchPosts { (posts) in
            
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                self.tableView.reloadData()
                completion?(posts != nil)
            }
        }
    }
    
    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toPostDetailVC",
            let indexPath = tableView.indexPathForSelectedRow,
            let destinationVC = segue.destination as? PostDetailTableViewController {
            let post = PostController.sharedInstance.posts[indexPath.row]
            destinationVC.post = post
        }
    }
}//End of class

//MARK: - Extensions
extension PostListTableViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        if !searchText.isEmpty {
            resultsArray = PostController.sharedInstance.posts.filter { $0.matches(searchTerm: searchText) }
            tableView.reloadData()
        } else {
            resultsArray = PostController.sharedInstance.posts
            tableView.reloadData()
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        
        resultsArray = PostController.sharedInstance.posts
        tableView.reloadData()
        searchBar.text = ""
        searchBar.resignFirstResponder()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        
        searchBar.resignFirstResponder()
        isSearching = false
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        
        isSearching = true
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        
        searchBar.text = ""
        isSearching = false
    }
}
