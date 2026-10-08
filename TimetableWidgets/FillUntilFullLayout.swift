//
//  FillUntilFullLayout.swift
//  Timetable
//
//  Created by Zack on 2026/10/7.
//

import SwiftUI

struct FillUntilFullLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews,
                      cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let maxHeight = proposal.height ?? .infinity

        var total: CGFloat = 0
        for subview in subviews {
            let h = subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
            let next = total == 0 ? h : total + spacing + h
            if next > maxHeight { break }
            total = next
        }
        return CGSize(width: width, height: total)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        let width = bounds.width

        let heights: [CGFloat] = subviews.map {
            $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        }

        var visibleHeight: CGFloat = 0
        var placedCount = 0
        for h in heights {
            let next = visibleHeight == 0 ? h : visibleHeight + spacing + h
            if next > bounds.height { break }
            visibleHeight = next
            placedCount += 1
        }

        let allFit = placedCount == heights.count

        let startY: CGFloat = allFit
            ? bounds.minY
            : bounds.minY + max(0, (bounds.height - visibleHeight) / 2)

        var y = startY
        for (i, subview) in subviews.enumerated() {
            let h = heights[i]
            if i < placedCount {
                subview.place(
                    at: CGPoint(x: bounds.minX, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: width, height: h)
                )
                y += h + spacing
            } else {
                subview.place(
                    at: CGPoint(x: bounds.minX, y: bounds.maxY + 10_000),
                    proposal: ProposedViewSize(width: 0, height: 0)
                )
            }
        }
    }
}
