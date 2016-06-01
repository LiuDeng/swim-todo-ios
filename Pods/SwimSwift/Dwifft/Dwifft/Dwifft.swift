//
//  LCS.swift
//  Dwifft
//
//  Created by Jack Flintermann on 3/14/15.
//  Copyright (c) 2015 jflinter. All rights reserved.
//
// Modified by Ewan Mellor for Swim.it.
//


struct Diff<T> {
    let results: [DiffStep<T>]
    var insertions: [DiffStep<T>] {
        return results.filter({ $0.isInsertion }).sort { $0.idx < $1.idx }
    }
    var deletions: [DiffStep<T>] {
        return results.filter({ !$0.isInsertion }).sort { $0.idx > $1.idx }
    }
    func reversed() -> Diff<T> {
        let reversedResults = self.results.reverse().map { (result: DiffStep<T>) -> DiffStep<T> in
            switch result {
            case .Insert(let i, let j):
                return .Delete(i, j)
            case .Delete(let i, let j):
                return .Insert(i, j)
            }
        }
        return Diff<T>(results: reversedResults)
    }
}

private func +<T> (left: Diff<T>, right: DiffStep<T>) -> Diff<T> {
    return Diff<T>(results: left.results + [right])
}

/// These get returned from calls to Array.diff(). They represent insertions or deletions that need to happen to transform array a into array b.
enum DiffStep<T> : CustomDebugStringConvertible {
    case Insert(Int, T)
    case Delete(Int, T)
    var isInsertion: Bool {
        switch(self) {
        case .Insert:
            return true
        case .Delete:
            return false
        }
    }
    var debugDescription: String {
        switch(self) {
        case .Insert(let i, let j):
            return "+\(j)@\(i)"
        case .Delete(let i, let j):
            return "-\(j)@\(i)"
        }
    }
    var idx: Int {
        switch(self) {
        case .Insert(let i, _):
            return i
        case .Delete(let i, _):
            return i
        }
    }
    var value: T {
        switch(self) {
        case .Insert(let j):
            return j.1
        case .Delete(let j):
            return j.1
        }
    }
}

class Dwifft {
    /// Returns the sequence of ArrayDiffResults required to transform one array into another.
    static func diff(mine: [SwimModelProtocolBase], _ other: [SwimModelProtocolBase]) -> Diff<SwimModelProtocolBase> {
        let table = Dwifft.buildTable(mine, other, mine.count, other.count)
        return Dwifft.diffFromIndices(table, mine, other, mine.count, other.count)
    }
    
    /// Walks back through the generated table to generate the diff.
    private static func diffFromIndices(table: [[Int]], _ x: [SwimModelProtocolBase], _ y: [SwimModelProtocolBase], _ i: Int, _ j: Int) -> Diff<SwimModelProtocolBase> {
        if i == 0 && j == 0 {
            return Diff<SwimModelProtocolBase>(results: [])
        } else if i == 0 {
            return diffFromIndices(table, x, y, i, j-1) + DiffStep.Insert(j-1, y[j-1])
        } else if j == 0 {
            return diffFromIndices(table, x, y, i - 1, j) + DiffStep.Delete(i-1, x[i-1])
        } else if table[i][j] == table[i][j-1] {
            return diffFromIndices(table, x, y, i, j-1) + DiffStep.Insert(j-1, y[j-1])
        } else if table[i][j] == table[i-1][j] {
            return diffFromIndices(table, x, y, i - 1, j) + DiffStep.Delete(i-1, x[i-1])
        } else {
            return diffFromIndices(table, x, y, i-1, j-1)
        }
    }

    private static func buildTable(x: [SwimModelProtocolBase], _ y: [SwimModelProtocolBase], _ n: Int, _ m: Int) -> [[Int]] {
        var table = Array(count: n + 1, repeatedValue: Array(count: m + 1, repeatedValue: 0))
        for i in 0...n {
            for j in 0...m {
                if (i == 0 || j == 0) {
                    table[i][j] = 0
                }
                else if x[i-1] === y[j-1] {
                    table[i][j] = table[i-1][j-1] + 1
                } else {
                    table[i][j] = max(table[i-1][j], table[i][j-1])
                }
            }
        }
        return table
    }
}
