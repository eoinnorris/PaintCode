//
//  File.swift
//  PaintShop
//
//  Created by Eoin Norris on 09/12/2017.
//  Copyright © 2017 Occasionally Useful Software. All rights reserved.
//

import Foundation

enum Finish{
    case Matte, Gloss
}

enum Color:Int{
    case number
}

enum PaintComparison{
    case match
    case colorMatchesFinishDifferent
    case noMatch
}

struct Paint:Equatable {
    let color: Color
    let finish: Finish
    
    static func ==(lhs: Paint, rhs: Paint) -> Bool {
        return ((lhs.color == rhs.color) && (lhs.finish == rhs.finish))
    }
    
     func compare(p1: Paint, p2: Paint) -> PaintComparison {
        if (p1 == p2) {
            return PaintComparison.match
        } else if ((p1.color == p2.color) && (p1.finish != p2.finish)) {
            return PaintComparison.colorMatchesFinishDifferent
        }
        
        return PaintComparison.noMatch
    }
    
    func uniqueID()->String{
        return "\(color):\(finish)"
    }
    
}

struct Customer:Equatable {
    let uniqueID:Int
    var requirements:[Paint]
    
    
    static func ==(lhs: Customer, rhs: Customer) -> Bool {
        return lhs.uniqueID == rhs.uniqueID
    }
    
    func wantsSinglePaint()->Bool{
        return (requirements.count == 1)
    }
    
    func paintAt(_ index:Int)->Paint{
        return requirements[index]
    }
}


struct PaintMix {
    var paints:[Paint]
    
    mutating func replace(_ paint:Paint){
       paints[paint.color.rawValue] = paint
    }
    func uniqueID()->String{
        var result = ""
        for paint in paints {
            result += paint.uniqueID()
        }
        return result;
    }

}

struct Solution {
    var paintMix:PaintMix
    var error = ""
    var needsToReset = false
    
    // an array of paints that cannot change, for instance if a customer only wants one paint 1G, that is locked. Any attempt to change it wil cause an error
    var fulfilledPaints:[Paint] // indices into the paints that cannot ever be changed
    var fulfilledCustomers:[Customer]    // a customer who has caused a fufilled paint(s) and cant be changed
    var tempFufilledCustomers:[Customer] // customers who were fufilled by the most recent candidate
    var failedPaintMixes:[String:PaintMix] // previously tried paint mixes that didnt succeed for all customers
    
    func fufilledPaintFor(_ color:Color)->Paint?{
        var result:Paint? = nil
        
        for paint in fulfilledPaints {
            if (paint.color == color){
                result = paint
                break
            }
        }
        return result
    }
    
    mutating func addToFufilledList(customer:Customer, paint:Paint) {
        fulfilledPaints.append(paint)
        fulfilledCustomers.append(customer)
    }
    
    mutating func addToFailed(_ failedMix:PaintMix){
        failedPaintMixes[failedMix.uniqueID()] = failedMix
    }
    
    private func hasFailed(paintMix:PaintMix)->Bool{
        return (failedPaintMixes[paintMix.uniqueID()] != nil)
    }
    
    private func paintMixByReplacing(paint:Paint)->PaintMix{
        var paintMixNew = paintMix
        paintMixNew.replace(paint)
        return paintMix
    }
    
    func failedAlready(_ paint:Paint)->Bool{
        let paintMix = paintMixByReplacing(paint: paint)
        return hasFailed(paintMix: paintMix)
    }
    
    mutating func add(_ paint:Paint)throws{
        paintMix.replace(paint)
    }
    
}

enum SolutionError: Error {
    case solutionImpossible
    case solutionFailed
}

enum ParsingError:Error {
    case invalidCustomerIndex
    case invalidFinishIndex
}

enum InputError:Error{
    case customerWithNoPaints
    case paintWithNoFinish
    case colorFinishMismatch
}


struct Solver {
    
    var customers:[Customer]
    let colors:[Color]
    var candidate:[PaintMix]
    let failureText = "No optimal solution"
    
    func getOriginalCandidate(_ numberOfColors:Int)->[Paint]{
        var result:[Paint] = []
        
        for index in 0...numberOfColors{
            if let  color = Color(rawValue: index) {
                result.append(Paint(color: color, finish: Finish.Gloss))
            }
        }
        
        return result
    }
    
    
    fileprivate func solveForMultiplePaints( _ customer: Customer, _ existingSolution: Solution) throws -> Solution {
        
        guard  customer.requirements.count > 0 else {
            throw  InputError.customerWithNoPaints
        }
        
        var potentialSolution = existingSolution
        let storedPaintMix = existingSolution.paintMix
        
        let notFufilledPaints = existingSolution.paintMix.paints.filter { (paint) -> Bool in
            return (potentialSolution.fufilledPaintFor(paint.color) == nil)
        }
        
        let fufilledPaints = existingSolution.paintMix.paints.filter { (paint) -> Bool in
            return (potentialSolution.fufilledPaintFor(paint.color) != nil)
        }
        
        var customerHadOneOption = false
        var replacedOrFoundPaint = false
        var changedPaint:Paint? = nil
        
        for index in 0...notFufilledPaints.count-1{
            customerHadOneOption = index == notFufilledPaints.count-1
            
            let candidatePaint = notFufilledPaints[index]
            let customerPaint = customer.paintAt(index)
            if (candidatePaint != customerPaint){
                if (potentialSolution.failedAlready(customerPaint) == false){
                    try potentialSolution.add(customerPaint)
                    potentialSolution.addToFailed(storedPaintMix)
                    changedPaint = customerPaint
                    replacedOrFoundPaint = true
                    break
                }
            }
        }
        
        if (replacedOrFoundPaint == true){
            if (customerHadOneOption){
                if let customerPaint = changedPaint{
                    // this customer had to change a paint, and only one paint satisifed.
                    // That paint and the customer are now locked.
                    potentialSolution.addToFufilledList(customer: customer, paint: customerPaint)
                }
            }
            potentialSolution.needsToReset = true
        } else {
            var foundMatch = false
            for index in 0...fufilledPaints.count-1{
                customerHadOneOption = index == notFufilledPaints.count-1
                
                let changablePaint = notFufilledPaints[index]
                let customerPaint = customer.paintAt(index)
                if (changablePaint == customerPaint){
                   foundMatch = true
                    break
                }
            }
            
            if (foundMatch == false){
                throw SolutionError.solutionImpossible
            }
        }
        
        
        return potentialSolution
        
    }
  
fileprivate func solveForSinglePaint( _ customer: Customer, _ existingSolution: Solution) throws -> Solution {
    guard  customer.requirements.count > 0 else {
        throw  InputError.customerWithNoPaints
    }
    var potentialSolution = existingSolution
    let paint = customer.requirements[0]

    guard paint.color.rawValue < customer.requirements.count else {
        throw  ParsingError.invalidCustomerIndex
    }
    
    if (potentialSolution.fulfilledPaints.contains(paint) == true){
        // this customer is fufilled already by his paint and that cant change so lets not try him again
        potentialSolution.fulfilledCustomers.append(customer)
    } else {
        // we dont have an equivalent paint for this guy
        // a paint contains color and finish, do we have a color at this index
        if let satisifedPaint = potentialSolution.fufilledPaintFor(paint.color){
            //  we have a fufilled color for this paint which cant change
            if (satisifedPaint.finish != paint.finish) {
                // but the finish is different
                throw SolutionError.solutionImpossible
            }
        } else {
            // no paint or color exists at this position
            try potentialSolution.add(paint)
            potentialSolution.fulfilledPaints.append(paint)
            potentialSolution.fulfilledCustomers.append(customer)
        }
    }
            // if it does exist in that list we dont have to change it.
    
        return potentialSolution
    
    }
        
    
    
  
    
fileprivate func solveFor(potentialSolution:Solution?, _ customers:[Customer], numberOfColors:Int) throws -> Solution{
        
        var solutionOpt:Solution? = nil
        
        if potentialSolution != nil{
            // starting paints are the number paints all gloss
            let startingPaints = getOriginalCandidate(numberOfColors)
            
            // lets sort the customers by their smaller requirement
            let candidate = PaintMix(paints: startingPaints)
            
            solutionOpt = Solution(paintMix: candidate, error: "", needsToReset: false, fulfilledPaints: [], fulfilledCustomers: [], tempFufilledCustomers: [], failedPaintMixes: [:])
            
            
        } else {
            solutionOpt = potentialSolution
        }
        
        var solution = solutionOpt!
    
    // we just need to parse the customers that are not already locked down
    // a fufilled customer is one who has requirements met because one fufilled paint
    // matches his requirements and needs to be there
        let notSatisfiedCustomers = customers.filter { (customer) -> Bool in
            return (solution.fulfilledCustomers.contains(customer) == false)
        }
    
    // sort the customers by size of paints to better handle customers with one paint requirement
    // customers with one paint requirement generate a fufilled paint immediately and become fufilled customers immediately, or if there is a conflict cause an exception immediately
        let customers = notSatisfiedCustomers.sorted { (c1, c2) -> Bool in
            return (c1.requirements.count <= c2.requirements.count)
        }
    
        var needsToReset = true
    
        for customer in customers {
            if (customer.wantsSinglePaint()){
                solution = try solveForSinglePaint(customer, solution)
            } else {
                solution = try solveForMultiplePaints(customer, solution)
                if (solution.needsToReset == true){
                    needsToReset = true
                    break
                }
            }
        }
    
        if needsToReset == true{
            solution.needsToReset = false
            solution.tempFufilledCustomers = []
            solution = try solveFor(potentialSolution: solution, customers, numberOfColors: numberOfColors)
        }
    
    
        return solution

    }
}


















