//
//  TableViewController.swift
//  ObjectDetectionYOLO
//
//  Created by Andi Xu on 12/23/21.
//

import UIKit
import AVFoundation
class SelectTableView: UITableViewController, UISearchBarDelegate {
    @IBOutlet weak var searchBar: UISearchBar!
    
    
    let list = ["laptop", "diningtable", "sofa", "toilet", "bed", "cell phone", "cat", "chair", "keyboard", "bench", "person", "suitcase", "bicycle", "car", "motorbike", "aeroplane", "bus", "train", "truck", "boat", "traffic light", "fire hydrant", "stop sign", "parking meter", "bird", "dog", "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack", "umbrella", "handbag", "tie", "frisbee", "skis", "snowboard", "sports ball", "kite", "baseball bat", "baseball glove", "skateboard", "surfboard", "tennis racket", "bottle", "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple", "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "pottedplant", "tvmonitor", "mouse", "remote", "microwave", "oven", "toaster", "sink", "refrigerator", "book", "clock", "vase", "scissors", "teddy bear", "hair drier", "toothbrush"].sorted()
    var selected: Set<String> = []
    
    var searchActive : Bool = false
    var filtered:[String] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.allowsMultipleSelection = true
        //self.tableView.allowsMultipleSelectionDuringEditing = true
        searchBar.delegate = self
    }

    

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if(searchActive) {
            return filtered.count
        }
        return list.count;
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        if(searchActive ) {
            cell.textLabel?.text=filtered[indexPath.row]
        } else{
            cell.textLabel?.text=list[indexPath.row]
        }
        
        cell.selectionStyle = .none
        
        if selected.contains(cell.textLabel?.text ?? "")
        {
            cell.accessoryType = .checkmark

        } else {
            cell.accessoryType = .none
        }
        return cell
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "toVideoCapture") {
            let vc = segue.destination as! ViewController
            vc.requiredItem = selected
        }
    }
    
    // Select
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print(indexPath)
        let cell = tableView.cellForRow(at: indexPath)
        print(cell)
        if (cell!.accessoryType == .none){
            cell!.accessoryType = .checkmark
        }
        
        selected.insert(cell!.textLabel!.text ?? "")
        let text = cell!.textLabel!.text ?? ""
        playSound(str: String(format: "Select %@", text))
        
    }
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        print(indexPath)
        let cell = tableView.cellForRow(at: indexPath)
        
        if (cell!.accessoryType == .checkmark){
            cell!.accessoryType = .none
        }
        let text = cell!.textLabel!.text ?? ""
        selected.remove(text)
        playSound(str: String(format: "Deselect %@", text))
    }
    
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchActive = true;
   }

   func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
       searchActive = false;
   }

   func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
       searchActive = false;
       searchBar.resignFirstResponder()
   }

   func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
       searchActive = false;
       searchBar.resignFirstResponder()
   }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filtered = list.filter({ (text) -> Bool in
            let tmp: NSString = NSString(string: text)
            let range = tmp.range(of: searchText, options: NSString.CompareOptions.caseInsensitive)
           return range.location != NSNotFound
       })
       if(filtered.count == 0){
           searchActive = false;
       } else {
           searchActive = true;
       }
       self.tableView.reloadData()
   }
    func playSound( str: String ){
        let utterance = AVSpeechUtterance(string: str)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }

}
