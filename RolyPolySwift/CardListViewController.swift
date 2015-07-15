//
//  CardListViewController.swift
//  RolyPolySwift
//
//  Created by Dmitry Fedoseev on 22.03.15.
//  Copyright (c) 2015 Dmitry Fedoseev. All rights reserved.
//

import Foundation
import UIKit

enum Direction {
    case Left
    case Right
}

@objc protocol CardListDataSourceProtocol  {
    func numberOfCardsForCardList(cardList: CardListViewController) -> Int
    func cardForItemAtIndex(cardList: CardListViewController, index: Int) -> UIView
    func removeCardAtIndex(cardList: CardListViewController, index: Int)
    
    optional func heightForCardAtIndex(cardList: CardListViewController, index: Int) -> CGFloat
}

////////////////////////////////////////////////////////////////////////////

@objc protocol CardListDelegate {
    
}

////////////////////////////////////////////////////////////////////////////

class CardListViewController: UIViewController, UIScrollViewDelegate, UIGestureRecognizerDelegate {


    var dataSource: CardListDataSourceProtocol?
    var delegate: CardListDelegate?
    
    var padding: CGFloat {
        return 25
    }
    var cardWidth: CGFloat {
        return (self.view.frame.size.width - 20)
    }
    var defaultCardHeight: CGFloat {
        return 250
    }
    
    lazy var numberOfCards: Int = {
        var tempNumberOfCards = self.dataSource!.numberOfCardsForCardList(self)
        return tempNumberOfCards
    }()
    
    
    lazy var cardPositions: NSMutableArray = {
        var tempCardPositions = NSMutableArray()
        
        for var i = 0; i < self.numberOfCards; i++ {
            var position = Float(self.padding)
            if i > 0 {
                var positionOfPreviousCard: NSNumber = tempCardPositions.objectAtIndex(i - 1) as! NSNumber
                var heightOfPreviousCard: NSNumber = self.cardHeights.objectAtIndex(i - 1) as! NSNumber
                
                position += positionOfPreviousCard.floatValue + heightOfPreviousCard.floatValue
            }
            tempCardPositions.addObject(NSNumber(float: position))
        }
        return tempCardPositions
    }()
    
    lazy var cardHeights: NSMutableArray = {
        var tempCardHeights = NSMutableArray()
        
        for var i = 0; i < self.numberOfCards; i++ {
            var height = Float(self.defaultCardHeight)
            
            if let tempDataSource = self.dataSource {
                if let methodHeightForCardAtIndex = tempDataSource.heightForCardAtIndex {
                    height = Float(methodHeightForCardAtIndex(self, index: i))
                }
            }
            tempCardHeights.addObject(NSNumber(float: height))
        }
        return tempCardHeights
        
    }()

    
    
    lazy var visibleCards: NSMutableDictionary = {
        var tempVisibleCards = NSMutableDictionary()
        return tempVisibleCards
        
    }()
    
    var slideDuration: CGFloat {
        return 0.4
    }
    var slideDelay: CGFloat {
        return 0.2
    }
    
    var indexOfFirstVisibleCard = Int()
    var indexOfLastVisibleCard = Int()
    var indexOfFurthestVisitedCard = Int()
    
    var isScrollingProgrammatically = Bool()
    
    
    
    // MARK: - Default Initializer
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        // Here you can init your properties
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
//    override init () {
//        super.init()
//    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    convenience init(dataSource: CardListDataSourceProtocol?, delegate: CardListDelegate?) {
        self.init()
        self.dataSource = dataSource
        self.delegate = delegate
    }
    
    // MARK: - View Lifecycle
    
    override func loadView() {
        let scrollView = self.createScrollView()
        scrollView.delegate = self
        self.view = scrollView
        
        self.loadInitiallyVisibleCards()
    }
    
    // MARK: - Scroll View Delegate Methods
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        if self.isScrollingProgrammatically || self.numberOfCards <= 0 {
            return
        }
        
        while self.shouldDecrementIndexOfFirstVisibleCard() {
            self.indexOfFirstVisibleCard -= 1
            self.loadCardAtIndex(self.indexOfFirstVisibleCard, animated: false)
        }
        
        while self.shouldIncrementIndexOfFirstVisibleCard() {
            self.unloadCardAtIndex(self.indexOfFirstVisibleCard)
            self.indexOfFirstVisibleCard += 1
        }
        
        // update index of last visible card
        while self.shouldIncrementIndexOfLastVisibleCard() {
            self.indexOfLastVisibleCard += 1
            let animated = self.indexOfLastVisibleCard > self.indexOfFurthestVisitedCard
            self.loadCardAtIndex(self.indexOfLastVisibleCard, animated: animated)
        }
        
        while self.shouldDecrementIndexOfLastVisibleCard() {
            self.unloadCardAtIndex(self.indexOfLastVisibleCard)
            self.indexOfLastVisibleCard -= 1
        }

    }
    
    // MARK: - Loading and Unloading Cards
    
    func loadInitiallyVisibleCards() {
        self.loadCardAtIndex(self.indexOfLastVisibleCard, animated: true)
        
        var delay = 0.3
        
        while self.shouldIncrementIndexOfLastVisibleCard() {
            self.indexOfLastVisibleCard += 1
            let index = self.indexOfLastVisibleCard
            
            let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
            dispatch_after(delayTime, dispatch_get_main_queue()) {
                self.loadCardAtIndex(index, animated: true)
            }
            
            delay += 0.3
        }
    }

    func loadCardAtIndex(index: Int, animated: Bool) {
        let card: UIView = self.dataSource!.cardForItemAtIndex(self, index: index)
        let width: CGFloat = self.cardWidth
        let height: CGFloat = CGFloat(self.cardHeights.objectAtIndex(index).floatValue)
        let x: CGFloat = self.view.center.x - width / 2
        let y: CGFloat = CGFloat(self.cardPositions.objectAtIndex(index).floatValue)
        

        card.frame = CGRectMake(x, y, width, height)
        
        let panRecognizer = UIPanGestureRecognizer(target: self, action:"handlePanFromRecognizer:")
        panRecognizer.delegate = self
        card.addGestureRecognizer(panRecognizer)
        
        let key = NSNumber(integer: index)
      
        self.visibleCards.setObject(card, forKey: key)
        self.view.addSubview(card)
        
        if animated {
            self.slideCardIntoPlace(card)
        }
        
        if index > self.indexOfFurthestVisitedCard {
            self.indexOfFurthestVisitedCard = index;
        }

    }
    
    func unloadCardAtIndex(index: Int) {
        let key: NSNumber = NSNumber(integer: index)
        let card: UIView = self.visibleCards.objectForKey(key) as! UIView
        
        self.visibleCards.removeObjectForKey(key)
        card.removeFromSuperview()
    }
    
    func slideCardIntoPlace(card: UIView) {
        struct Static {
            static var enterFromLeft = false
        }
        
        Static.enterFromLeft = !Static.enterFromLeft
        
        let scrollView: UIScrollView = self.view as! UIScrollView
        let yOffset = 200 + scrollView.contentOffset.y + scrollView.frame.size.height - card.frame.origin.y
        
        
        card.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0, yOffset),CGAffineTransformMakeRotation(CGFloat(Static.enterFromLeft ? M_PI/10 : -M_PI/10)))
        
        UIView.animateWithDuration(Double(self.slideDuration), delay: Double(self.slideDelay), options: .CurveEaseOut, animations: { () -> Void in
            card.transform = CGAffineTransformIdentity
            }, completion: nil)
        }
    
    // MARK: - Swipe To Delete Cards
    
    func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        let panRecognizer = gestureRecognizer as! UIPanGestureRecognizer
        
        let translation = panRecognizer.translationInView(self.view)
        let x: CGFloat = translation.x
        let y: CGFloat = translation.y
        let slopeLessThanOneThird: Bool = fabs(y/x) < 1.0/3.0
        let slopeUndefined: Bool = x == 0 && y == 0
        return slopeLessThanOneThird || slopeUndefined
    }
    
    func handlePanFromRecognizer(recognizer: UIPanGestureRecognizer) {
        let deleteThreshold: CGFloat = 190.0
        
        let card: UIView = recognizer.view!
        
        let horizontalOffset: CGFloat = recognizer.translationInView(self.view).x

        let direction: Direction = horizontalOffset < 0 ? .Left : .Right
      
        let angle: CGFloat = self.angleForHorizontalOffset(horizontalOffset)
        let alpha: CGFloat = self.alphaForHorizontalOffset(horizontalOffset)
        
        card.transform = CGAffineTransformConcat(CGAffineTransformMakeRotation(angle), CGAffineTransformMakeTranslation(horizontalOffset, 0))
        
        card.alpha = alpha;
        
        if recognizer.state == .Ended {
            if fabs(horizontalOffset) > deleteThreshold {
                self.slideCardOffScreeninDirection(card, direction: direction, completion: { (finished: Bool) -> Void in
                    self.deleteCard(card)
                })
            } else {
                self.returnCardToOriginalState(card)
            }
        }
    }
    
    func angleForHorizontalOffset(horizontalOffset: CGFloat) -> CGFloat {
        
        let rotationThreshold: CGFloat = 70
        
        let direction: CGFloat = horizontalOffset >= 0 ? 1.0 : -1.0
        let tempHorizontalOffset: CGFloat = fabs(horizontalOffset)
        
        if tempHorizontalOffset < rotationThreshold {
            return 0
        }
        
        let angle = (direction * (tempHorizontalOffset - rotationThreshold) * CGFloat((M_PI/1000)))
        return angle
    }
    
    func alphaForHorizontalOffset(horizontalOffset: CGFloat) -> CGFloat {
        let alphaThreshold: CGFloat = 70
        
        let tempHorizontalOffset: CGFloat = fabs(horizontalOffset);
        
        if (tempHorizontalOffset < alphaThreshold) {
            return 1.0;
        }
        
        let alpha = (CGFloat(pow(CGFloat(M_E), -pow(CGFloat((tempHorizontalOffset - alphaThreshold)/125), CGFloat(2)))));
        
        return alpha
    }
    
    func returnCardToOriginalState(card: UIView) {
        UIView.animateWithDuration(0.3, delay: 0, options: .CurveEaseInOut, animations: { () -> Void in
            card.transform = CGAffineTransformIdentity
            card.alpha = 1.0
            }, completion: nil)
        
    }
    
    func slideCardOffScreeninDirection(card: UIView, direction: Direction, completion:(finished: Bool) -> Void)
    {
        var finalOffset: CGFloat = 1.5 * self.view.frame.size.width
        if direction == .Left {
            finalOffset *= -1
        }
        let finalAngle: CGFloat = self.angleForHorizontalOffset(finalOffset)
        let finalAlpha: CGFloat = self.alphaForHorizontalOffset(finalOffset)
        
        UIView.animateWithDuration(0.3, delay: 0, options: .CurveEaseIn, animations: { () -> Void in
            card.transform = CGAffineTransformConcat(CGAffineTransformMakeRotation(finalAngle),
            CGAffineTransformMakeTranslation(finalOffset, 0))
            card.alpha = finalAlpha
        }, completion: completion)
    }
    
    
    func deleteCard(card: UIView) {
        
        let index: Int = self.indexForVisibleCard(card)
        let oldCardPositions: NSMutableArray = NSMutableArray(array: self.cardPositions)
        oldCardPositions.removeObjectAtIndex(index)
        
        self.removeStateForCardAtIndex(index)
        let overlap: CGFloat = self.makeScrollViewShorter()
        
        if self.numberOfCards <= 0 {
            return
        }
        self.updateVisibleCardsAfterCardRemovedFromIndex(index)
        
        // put visible cards in their old positions
        
        for var visibleCardIndex: Int = self.indexOfFirstVisibleCard; visibleCardIndex <= self.indexOfLastVisibleCard; visibleCardIndex++ {
            let card: UIView = self.visibleCards.objectForKey(NSNumber(integer: visibleCardIndex)) as! UIView
            let x: CGFloat = card.frame.origin.x
            let y: CGFloat = (CGFloat((oldCardPositions.objectAtIndex(visibleCardIndex) as! NSNumber).floatValue) - overlap)
            let width: CGFloat = card.frame.size.width
            let height: CGFloat = card.frame.size.height
            card.frame = CGRectMake(x, y, width, height)
            
        }
        self.fillEmptySpaceLeftByCardAtIndex(index)
    }
    
    func removeStateForCardAtIndex(index: Int) {
        self.dataSource?.removeCardAtIndex(self, index: index)
        self.unloadCardAtIndex(index)
        self.numberOfCards--
        
        let removedCardHeight: CGFloat = CGFloat((self.cardHeights.objectAtIndex(index) as! NSNumber).floatValue)
        self.cardHeights.removeObjectAtIndex(index)
        
        self.cardPositions.removeObjectAtIndex(index)
        for var i: Int = index; i < self.cardPositions.count; i++ {
            var position = CGFloat((self.cardPositions.objectAtIndex(i) as! NSNumber).floatValue)
            position -= removedCardHeight + self.padding
            let tempPosition = Float(position)
            self.cardPositions.replaceObjectAtIndex(i, withObject: NSNumber(float: tempPosition))
        }
        
        self.indexOfLastVisibleCard--
        
        let keysInOrder: NSArray = self.visibleCards.allKeys.sort { ( a: AnyObject,  b: AnyObject) -> Bool in
            let c: NSNumber = a as! NSNumber
            let d: NSNumber = b as! NSNumber
            return c.floatValue < d.floatValue
        }
        
        for key in keysInOrder {
            var cardIndex: Int = key.integerValue
            if (cardIndex > index) {
                let card: UIView = self.visibleCards.objectForKey(key) as! UIView
                self.visibleCards.removeObjectForKey(key)
                cardIndex--
                let newKey: NSNumber = NSNumber(integer: cardIndex)
                self.visibleCards.setObject(card, forKey: newKey)
            }
        }

    }
    
    func updateVisibleCardsAfterCardRemovedFromIndex(index: Int) {
        
        
        while self.shouldIncrementIndexOfFirstVisibleCard() {
            self.unloadCardAtIndex(self.indexOfFirstVisibleCard)
            self.indexOfFirstVisibleCard += 1;
        }
        
        while self.shouldDecrementIndexOfFirstVisibleCard() {
            self.indexOfFirstVisibleCard -= 1;
            self.loadCardAtIndex(self.indexOfFirstVisibleCard, animated:false)
        }
        
        while self.shouldIncrementIndexOfLastVisibleCard() {
            self.indexOfLastVisibleCard += 1;
            self.loadCardAtIndex(self.indexOfLastVisibleCard, animated:false)
        }
        
        while self.shouldDecrementIndexOfLastVisibleCard() {
            self.unloadCardAtIndex(self.indexOfLastVisibleCard)
            self.indexOfLastVisibleCard -= 1;
        }

    }
    
    func makeScrollViewShorter() -> CGFloat {
        
        let scrollView: UIScrollView = self.view as! UIScrollView
        
        let bottomOfScrollView: CGFloat = scrollView.contentSize.height
        let bottomOfScreen: CGFloat = scrollView.contentOffset.y + scrollView.frame.size.height
        let bottomOfScreenToBottomOfScrollView: CGFloat = max(0, bottomOfScrollView - bottomOfScreen)
        
        var heightOfAllCards: CGFloat = 0
        
        for cardHeight in self.cardHeights {
            heightOfAllCards += CGFloat(cardHeight.floatValue)
        }
        let spaceLeftByRemovedCard: CGFloat = scrollView.contentSize.height - heightOfAllCards - CGFloat((self.numberOfCards + 1)) * self.padding
        
        let amountScrollViewHeightWillChange: CGFloat = min(scrollView.contentSize.height - scrollView.frame.size.height, spaceLeftByRemovedCard)

        let overlap: CGFloat = max(0, bottomOfScreen - (bottomOfScrollView - amountScrollViewHeightWillChange))
        
        // make scrollView shorter
        
        let removedRegionOverlapsVisibleRegion: Bool = bottomOfScreenToBottomOfScrollView < amountScrollViewHeightWillChange
       
        if removedRegionOverlapsVisibleRegion == true {
            self.isScrollingProgrammatically = true
            scrollView.contentOffset = CGPointMake(scrollView.contentOffset.x, scrollView.contentOffset.y - overlap)
            self.isScrollingProgrammatically = false
        }
        
        scrollView.contentSize = CGSizeMake(scrollView.contentSize.width, scrollView.contentSize.height - amountScrollViewHeightWillChange)
        
        return overlap

    }
    
    func fillEmptySpaceLeftByCardAtIndex(index: Int) {
        
        let sortedKeys: NSArray = self.visibleCards.allKeys.sort { (a: AnyObject, b: AnyObject) -> Bool in
            let c = a as! NSNumber
            let d = b as! NSNumber
            
            let distanceFromAToRemovedCard: NSNumber = NSNumber(integer: abs(c.integerValue - index))
            let distanceFromBToRemovedCard: NSNumber = NSNumber(integer: abs(d.integerValue - index))
            return distanceFromAToRemovedCard.floatValue < distanceFromBToRemovedCard.floatValue
        }
        
        var delay = 0.0
        
        for key in sortedKeys {
            let card: UIView = self.visibleCards.objectForKey(key) as! UIView
            let oldPosition: CGFloat = card.frame.origin.y
            let newPosition: CGFloat = CGFloat((self.cardPositions.objectAtIndex(key.integerValue) as! NSNumber).floatValue)
            let needsToBeMoved: Bool = oldPosition != newPosition
            
            if needsToBeMoved {
                card.frame = CGRectMake(card.frame.origin.x, newPosition, card.frame.size.width, card.frame.size.height)
                card.transform = CGAffineTransformMakeTranslation(0, oldPosition - newPosition)
                let duration = 0.5
                
                UIView.animateWithDuration(duration, delay: delay, options: .CurveEaseInOut, animations: { () -> Void in
                    card.transform = CGAffineTransformIdentity
                    }, completion: nil)
                
                
                // rotation
                let angle: CGFloat = newPosition < oldPosition ? CGFloat(1*(M_PI/180)) : CGFloat(-1*(M_PI/180))
                let rotationAnimation: CAKeyframeAnimation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
                rotationAnimation.duration = Double(duration)
                rotationAnimation.beginTime = CACurrentMediaTime() + Double(delay) + 0.01
                rotationAnimation.calculationMode = kCAAnimationCubic
                rotationAnimation.values = [NSNumber(float: 0.0),
                    NSNumber(float: Float(angle)),
                    NSNumber(float: Float(angle)),
                    NSNumber(float: 0.0)]
                
                rotationAnimation.keyTimes = [NSNumber(float: 0.0),
                    NSNumber(float: 0.35),
                    NSNumber(float: 0.65),
                    NSNumber(float: 1.0)]
                
                card.layer.addAnimation(rotationAnimation, forKey: nil)
                delay += 0.2
            }
        }

    }
    
    // MARK: - Card Visibility
    
    func shouldDecrementIndexOfFirstVisibleCard() -> Bool {
        let scrollView = self.view as! UIScrollView
        
        let positionOfFirstVisibleCard = self.cardPositions.objectAtIndex(self.indexOfFirstVisibleCard) as! NSNumber
        
        let cardAboveIsVisible: Bool = CGFloat(positionOfFirstVisibleCard.floatValue) - scrollView.contentOffset.y > self.padding
        

        let isFirstCardInList: Bool = self.indexOfFirstVisibleCard == 0
        
        return cardAboveIsVisible && !isFirstCardInList
    }
    
    func shouldIncrementIndexOfFirstVisibleCard() -> Bool {
        let scrollView = self.view as! UIScrollView
        
        let positionOfFirstVisibleCard = self.cardPositions.objectAtIndex(self.indexOfFirstVisibleCard) as! NSNumber
        let heightOfFirstVisibleCard = self.cardHeights.objectAtIndex(self.indexOfFirstVisibleCard) as! NSNumber
        
        let cardIsNotVisible: Bool = CGFloat(positionOfFirstVisibleCard.floatValue) + CGFloat(heightOfFirstVisibleCard.floatValue) <= scrollView.contentOffset.y
        
        let isLastCardInList: Bool = self.indexOfFirstVisibleCard == self.numberOfCards - 1
        return cardIsNotVisible && !isLastCardInList
    }
    
    func shouldDecrementIndexOfLastVisibleCard() -> Bool {
        let scrollView = self.view as! UIScrollView
        
        let positionOfLastVisibleCard = self.cardPositions.objectAtIndex(self.indexOfLastVisibleCard) as! NSNumber
        
        let positionOfScreenBottom = scrollView.contentOffset.y + scrollView.frame.size.height
        
        let cardIsNotVisible: Bool = CGFloat(positionOfLastVisibleCard.floatValue) > positionOfScreenBottom
        let isFirstCardInList: Bool = self.indexOfLastVisibleCard == 0
        
        return cardIsNotVisible && !isFirstCardInList
    }
    
    func shouldIncrementIndexOfLastVisibleCard() -> Bool {
        let scrollView = self.view as! UIScrollView
        
        let positionOfLastVisibleCard = self.cardPositions.objectAtIndex(self.indexOfLastVisibleCard) as! NSNumber
        
        let heightOfLastVisibleCard = self.cardHeights.objectAtIndex(self.indexOfLastVisibleCard) as! NSNumber
        let positionOfScreenBottom = scrollView.contentOffset.y + scrollView.frame.size.height
        let positionOfCardBottom = CGFloat(positionOfLastVisibleCard.floatValue + heightOfLastVisibleCard.floatValue)
        
        let cardBelowIsVisble: Bool = positionOfScreenBottom - positionOfCardBottom > self.padding
        let isLastCardInList: Bool = self.indexOfLastVisibleCard == self.numberOfCards - 1
        
        return cardBelowIsVisble && !isLastCardInList
    }
        
    
    // MARK: - Helpers
    
    func createScrollView() -> UIScrollView {
        
        let fullScreenRect: CGRect = UIScreen.mainScreen().applicationFrame
        let scrollView = UIScrollView(frame: fullScreenRect)
        
        scrollView.backgroundColor = UIColor(red: 0.898, green: 0.898, blue: 0.898, alpha: 1.0)
        scrollView.alwaysBounceVertical = true
        
        let contentWidth = UIScreen.mainScreen().applicationFrame.size.width
        var contentHeight: CGFloat = self.padding
        
        for cardHeight in self.cardHeights {
            contentHeight += self.padding
            contentHeight += CGFloat(cardHeight.floatValue)
        }
   
        
        scrollView.contentSize = CGSizeMake(contentWidth, contentHeight)
        
        return scrollView
    }
    
    func indexForVisibleCard(card: UIView) -> Int {
        var index: Int = self.indexOfFirstVisibleCard
        
        while index < self.indexOfLastVisibleCard {
            let key = NSNumber(integer: index)
            
            if self.visibleCards.objectForKey(key) as! UIView == card {
                break
            }
            index++
        }
        return index
    }
    
    func frameForCardAtIndex(index: Int) -> CGRect {
        return CGRectMake(0, 0, 0, 0)
    }
}
