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
    
    
}

struct Customer:Equatable {
    let uniqueID:Int
    var requirements:[Paint]
    
    
    static func ==(lhs: Customer, rhs: Customer) -> Bool {
        return lhs.uniqueID == rhs.uniqueID
    }
}


struct PaintMix {
    var candidate:[Finish]
    
    mutating func replacePaint(paint:Paint){
       candidate[paint.color.rawValue] = paint.finish
    }
}

struct Solution {
    var candidate:PaintMix?
    var error = ""
    
    // an array of paints that cannot change, for instance if a customer only wants 1G, that is locked. Any attempt to change it wil cause an error
    var fufilledPaints:[Paint] // indices into the paints that cannot ever be changed
 
    var fufilledCustomers:[Customer]    // a customer who has caused a fufilled paint(s)
    
    var failedPaintMixes:[PaintMix]? // previously tried paints
    
    func fufilledPaintFor(_ color:Color)->Paint?{
        var result:Paint? = nil
        
        for paint in fufilledPaints {
            if (paint.color == color){
                result = paint
                break
            }
        }
        return result
    }
    
 func add(paint:Paint, toCandidate candidate:PaintMix)throws{
        var candidate = candidate
        candidate.replacePaint(paint: paint)
    }
    
}

enum SolutionError: Error {
    case solutionImpossible
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
    
    func getOriginalCandidate(_ numberOfColors:Int)->[Finish]{
        var result:[Finish] = []
        
        for _ in 1...numberOfColors{
            result.append(Finish.Gloss)
        }
        
        return result
    }
    
    
    fileprivate func solveForMultiplePaints( _ customer: Customer, _ existingSolution: Solution) throws -> Solution {
        
        var potentialSolution = existingSolution
        
        
        guard  customer.requirements.count > 0 else {
            throw  InputError.customerWithNoPaints
        }
        
        let paint = customer.requirements[0]
        
        guard paint.color.rawValue < customer.requirements.count else {
            throw  ParsingError.invalidCustomerIndex
        }
        
        
        if let candidate = existingSolution.candidate{
            if (potentialSolution.fufilledPaints.contains(paint) == false){
                // we dont have an equivalent paint but do we have an equivalent color, with a potential conflict?
                if let satisifedPaint = potentialSolution.fufilledPaintFor(paint.color){
                    // if so throw
                    if (satisifedPaint.finish != paint.finish) {
                        throw SolutionError.solutionImpossible
                    } else {
                        // if not then we can add this paint and customer as satisifed
                        potentialSolution.fufilledPaints.append(paint)
                        potentialSolution.fufilledCustomers.append(customer)
                        potentialSolution.candidate = candidate
                    }
                }
            }
            
            // if it does exist in that list we dont have to change it.
        }
        
        return potentialSolution
        
    }
  
fileprivate func solveForSinglePaint( _ customer: Customer, _ existingSolution: Solution) throws -> Solution {
        
        var potentialSolution = existingSolution
    
    
        guard  customer.requirements.count > 0 else {
            throw  InputError.customerWithNoPaints
        }
    
        let paint = customer.requirements[0]

        guard paint.color.rawValue < customer.requirements.count else {
            throw  ParsingError.invalidCustomerIndex
        }
    

        if let candidate = existingSolution.candidate{
            if (potentialSolution.fufilledPaints.contains(paint) == false){
                // we dont have an equivalent paint but do we have an equivalent color, with a potential conflict?
                if let satisifedPaint = potentialSolution.fufilledPaintFor(paint.color){
                    // if so throw
                    if (satisifedPaint.finish != paint.finish) {
                        throw SolutionError.solutionImpossible
                    } else {
                        // if not then we can add this paint and customer as satisifed
                        potentialSolution.fufilledPaints.append(paint)
                        potentialSolution.fufilledCustomers.append(customer)
                        potentialSolution.candidate = candidate
                    }
                }
            }
            
            // if it does exist in that list we dont have to change it.
        }
    
        return potentialSolution
    
    }
        
    
    
  
    

func solveFor(potentialSolution:Solution?, _ customers:[Customer], numberOfColors:Int) throws -> Solution{
        
        var solutionOpt:Solution? = nil
        
        if potentialSolution != nil{
            // starting paints are the number paints all gloss
            let startingPaints = getOriginalCandidate(numberOfColors)
            
            // lets sort the customers by their smaller requirement
            let candidate = PaintMix(candidate: startingPaints)
            
            solutionOpt = Solution(candidate: candidate, error: "", fufilledPaints: [], fufilledCustomers: [], failedPaintMixes: [])
            
            
        } else {
            solutionOpt = potentialSolution
        }
        
        var solution = solutionOpt!
   
        
        let customers = customers.sorted { (c1, c2) -> Bool in
            return (c1.requirements.count <= c2.requirements.count)
        }
        
        for customer in customers {
            if (customer.requirements.count == 1) && (solution.fufilledCustomers.contains(customer) == false){
                solution = try solveForSinglePaint(customer, solution)
            } else {
                
            }
        }
        
        // get all customers who want one paint lock down the indices
        // if all indices are locked then try all available customers
        // for each single customer with only one option
        // does this solution satisfy
        // if it does continue
        // if it doesnt then
        // if there is only option to change ignoring locked indices then call  solveForCustomersWithOneOption and restart *
        // if there are more degrees of freedom then change the first index that is g, else M
        // If nothing can be changed throw.
        
        
        
        
        
        // * optimize by not restarting if the locked customers are the same as the visited customers.
        
        return solution

        
    }
    
  
    
   
    
}


















