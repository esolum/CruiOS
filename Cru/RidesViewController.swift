//
//  RidesViewController.swift
//  Cru
//
//  Created by Deniz Tumer on 4/14/16.
//  Copyright © 2016 Jamaican Hopscotch Mafia. All rights reserved.
//

import UIKit
import MRProgress
import DZNEmptyDataSet


class RidesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, DZNEmptyDataSetDelegate, DZNEmptyDataSetSource, SWRevealViewControllerDelegate {
    let roundTrip = "round-trip"
    let roundTripDirection = "both"
    let fromEvent = "from event"
    let toEvent = "to event"
    let driver = "driver"
    let rider = "rider"
    var refreshControl: UIRefreshControl!
    var rides = [Ride]()
    var ridesDroppedFrom = [Ride]()
    var events = [Event]()
    var tappedRide: Ride?
    var tappedEvent: Event?
    var noRideImage: UIImage?{
        didSet{
            ridesTableView.reloadData()
        }
    }
    @IBOutlet weak var menuButton: UIBarButtonItem!
    @IBOutlet weak var ridesTableView: UITableView!
    @IBOutlet weak var findRideButton: UIButton!
    @IBOutlet weak var offerRideButton: UIButton!
    var passMap: LocalStorageManager!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable ride sharing for release 1.4
        // Issue #135 - Enable Ridesharing
        #if RELEASE
        self.findRideButton.isHidden = true
        self.offerRideButton.isHidden = true
        #endif
        
        // Setup side menu
        GlobalUtils.setupViewForSideMenu(self, menuButton: self.menuButton)

        // Configure tableview
        self.ridesTableView.tableFooterView = UIView()
        self.ridesTableView.rowHeight = UITableViewAutomaticDimension
        self.ridesTableView.estimatedRowHeight = 75
        self.ridesTableView.separatorStyle = .none
        self.ridesTableView.emptyDataSetSource = self
        self.ridesTableView.emptyDataSetDelegate = self
        
        // Configure refresh control
        self.refreshControl = UIRefreshControl()
        self.refreshControl.attributedTitle = NSAttributedString(string: "")
        self.refreshControl.addTarget(self, action: #selector(self.refresh), for: UIControlEvents.valueChanged)
        self.ridesTableView.addSubview(self.refreshControl)
        
        // Reload data
        // Disable ride sharing for release 1.4
        // Issue #135 - Enable Ridesharing
        #if DEBUG
        MRProgressOverlayView.showOverlayAdded(to: self.view, animated: true)
        CruClients.getRideUtils().getMyRides(insertRide, afterFunc: finishRideInsert)
        #endif
        
        // Set image and refresh tableview
        self.noRideImage = UIImage(named: Config.noRidesImageName)!
        
        // Get the ride local storage manager
        self.passMap = RideUtils.getMyPassengerMaps()
        
        // Listen for remote notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.refresh), name: Config.notificationRidesUpdated, object: nil)
    }
    
// Disable ride sharing for release 1.4
// Issue #135 - Enable Ridesharing
#if RELEASE
    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        return NSAttributedString(string: "Coming Soon!! 🚙")
    }
#else
    func image(forEmptyDataSet scrollView: UIScrollView!) -> UIImage! {
        return noRideImage
    }
#endif
    
    @IBAction func handleOfferRide(_ sender: AnyObject){
        self.performSegue(withIdentifier: "offerridesegue", sender: self)
    }
    
    @IBAction func handleFindRide(_ sender: AnyObject){
        self.performSegue(withIdentifier: "findridesegue", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "offerridesegue"{
            //let destVC = segue.destinationViewController as! OfferOrEditRideViewController
            let destVC = segue.destination as! NewOfferRideViewController
            destVC.events = self.events
            destVC.rideVC = self
            
        }
        if segue.identifier == "findridesegue"{
            let destVC = segue.destination as? FilterByEventViewController
            destVC?.rideVC = self
        }
        if(segue.identifier == "riderdetailsegue") {
            
            let yourNextViewController = (segue.destination as! RiderRideDetailViewController)
            
            yourNextViewController.ride = tappedRide
            yourNextViewController.event = tappedEvent
            yourNextViewController.rideVC = self
            
        }
        
        if(segue.identifier == "driverdetailsegue") {
            
            //let yourNextViewController = (segue.destinationViewController as! DriverRideDetailViewController)
            
            let yourNextViewController = (segue.destination as! NewDriverRideDetailViewController)
            
            yourNextViewController.ride = tappedRide
            yourNextViewController.event = tappedEvent
            yourNextViewController.rideVC = self
        }
    }
    
    @objc func refresh() {
        rides.removeAll()
        ridesTableView.emptyDataSetDelegate = nil
        ridesTableView.emptyDataSetSource = nil
        ridesTableView.reloadData()
        CruClients.getRideUtils().getMyRides(insertRide, afterFunc: finishRideInsert)
        passMap = RideUtils.getMyPassengerMaps()
    }
    
    func finishRideInsert(_ type: ResponseType){
        if(self.refreshControl.isRefreshing){
            self.refreshControl?.endRefreshing()
        }
        
        switch type{
            case .noRides:
                self.ridesTableView.emptyDataSetSource = self
                self.ridesTableView.emptyDataSetDelegate = self
                noRideImage = UIImage(named: Config.noRidesImageName)!
                CruClients.getServerClient().getData(.Event, insert: insertEvent, completionHandler: finishInserting)
                MRProgressOverlayView.dismissOverlay(for: self.view, animated: true)
            
            case .noConnection:
                self.ridesTableView.emptyDataSetSource = self
                self.ridesTableView.emptyDataSetDelegate = self
                noRideImage = UIImage(named: Config.noConnectionImageName)!
                MRProgressOverlayView.dismissOverlay(for: self.view, animated: true)
                offerRideButton.isUserInteractionEnabled = false
                findRideButton.isUserInteractionEnabled = false
            
            default:
                self.ridesTableView.emptyDataSetSource = nil
                self.ridesTableView.emptyDataSetDelegate = nil
                CruClients.getServerClient().getData(.Event, insert: insertEvent, completionHandler: finishInserting)
        }
        
        rides.sort()
        self.ridesTableView.reloadData()
    }
    
    
    func insertRide(_ dict : NSDictionary) {
        let newRide = Ride(dict: dict)!
        
        let curDate = Date()
        
        //TODO - Figure out how to remove past rides from server
        
        if let pMap = passMap as? MapLocalStorageManager<String> {
            if(newRide.fcmId != Config.fcmId()){
                if let passId = pMap.object(forKey: newRide.id) as? String {
                    
                    //if dropped from ride
                    if(!newRide.isPassengerInRide(passId)){
                        ridesDroppedFrom.append(newRide)
                        pMap.removeElement(newRide.id)
                        passMap = RideUtils.getMyPassengerMaps()
                    }
                        
                    //if passenger in ride
                    else{
                        //Check if ride hasn't already happened
                        if (newRide.departureDate?.isGreaterThanDate(curDate.addDays(-1)))! {
                            rides.insert(newRide, at: 0)
                            self.ridesTableView.insertRows(at: [IndexPath(item: 0, section: 0)], with: .middle)
                        }
                    }
                }
            }
            else{
                
                //Check if ride hasn't already happened
                if (newRide.departureDate?.isGreaterThanDate(curDate.addDays(-1)))! {
                    //if driving a ride
                    rides.insert(newRide, at: 0)
                    self.ridesTableView.insertRows(at: [IndexPath(item: 0, section: 0)], with: .middle)
                }
                
            }
        }
        
        rides.sort()
    }
    
    
    func finishInserting(_ success: Bool){
        showDroppedRides()
        
        self.ridesTableView.beginUpdates()
        MRProgressOverlayView.dismissOverlay(for: self.view, animated: true)        
        self.ridesTableView.reloadData()
        self.ridesTableView.endUpdates()
    }
    
    func showDroppedRides(){
        if(ridesDroppedFrom.count > 0){
            var droppedMsg = ""
            
            if(ridesDroppedFrom.count == 1){
                droppedMsg += "Sorry, It looks like you were dropped from a ride to the following event: "
            }else{
                droppedMsg += "Sorry, It looks like you were dropped from a ride to the following events: "
            }
            
            for ride in ridesDroppedFrom{
                droppedMsg += getEventNameForEventId(ride.eventId) + "\n"
            }
            ridesDroppedFrom.removeAll()
            
            let droppedAlert = UIAlertController(title: droppedMsg, message: "", preferredStyle: UIAlertControllerStyle.alert)
            droppedAlert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
            self.present(droppedAlert, animated: true, completion: nil)
            
        }
        
        self.ridesTableView.emptyDataSetSource = self
        self.ridesTableView.emptyDataSetDelegate = self
        noRideImage = UIImage(named: Config.noRidesImageName)!
    }
    
    func insertEvent(_ dict : NSDictionary) {
        //create event
        let event = Event(dict: dict)
        
        //insert into event array
        if(event?.rideSharingEnabled == true){
            events.insert(event!, at: 0)
        }
    }
    
    func getEventNameForEventId(_ id : String)->String{
        
        for event in events{
            if(event.id != "" && event.id == id){
                return event.name
            }
        }
        
        return ""
    }
    
    func getEventForEventId(_ id : String)->Event{
        
        for event in events{
            if(event.id != "" && event.id == id){
                return event
            }
        }
        
        return Event()!
    }
    
    override func viewWillAppear(_ animated: Bool) {
        navigationItem.title = " My Rides"
        
        self.navigationController!.navigationBar.titleTextAttributes  = [ NSFontAttributeName: UIFont(name: Config.fontBold, size: 20)!, NSForegroundColorAttributeName: UIColor.white]
    }
    
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rides.count
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //load cell and ride associated with that cell
        let cell = tableView.dequeueReusableCell(withIdentifier: "ride", for: indexPath) as! RideTableViewCell
        let ride = rides[indexPath.row]
        
        
        
        cell.day.text = String(ride.day)
        cell.month.text = ride.month
        
        
        if(ride.fcmId == Config.fcmId()){
            cell.rideType.text = driver
            cell.icon.image  = UIImage(named: driver)
        }
        else
        {
            cell.rideType.text = rider
            cell.icon.image = UIImage(named: rider)
        }
        
        
        
        cell.eventTitle.text = getEventNameForEventId(ride.eventId)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tappedRide = rides[indexPath.row]
        tappedEvent = getEventForEventId((tappedRide?.eventId)!)
        tappedRide!.eventName = (tappedEvent?.name)!
        
        if(tappedRide?.fcmId == Config.fcmId()){
            self.performSegue(withIdentifier: "driverdetailsegue", sender: self)
        }
        else{
            self.performSegue(withIdentifier: "riderdetailsegue", sender: self)
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
        
    }
    
    //reveal controller function for disabling the current view
    func revealController(_ revealController: SWRevealViewController!, willMoveTo position: FrontViewPosition) {
        
        if position == FrontViewPosition.left {
            for view in self.view.subviews {
                view.isUserInteractionEnabled = true
            }
        }
        else if position == FrontViewPosition.right {
            for view in self.view.subviews {
                view.isUserInteractionEnabled = false
            }
        }
    }
}
