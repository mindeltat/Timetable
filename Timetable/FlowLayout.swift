//
//  FlowLayout.swift
//  Timetable
//
//  Created by Zack on 2026/10/1.
//

import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, in: maxWidth)
        let height = rows.last.map { $0.y + $0.rowHeight } ?? 0
        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews: subviews, in: bounds.width)
        for row in rows {
            for item in row.items {
                let point = CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y)
                subviews[item.index].place(at: point, anchor: .topLeading, proposal: .unspecified)
            }
        }
    }

    private func arrange(subviews: Subviews, in maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        var x: CGFloat = 0
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if x + size.width > maxWidth, !current.items.isEmpty {
                rows.append(current)
                current = Row(y: rows.reduce(0) { $0 + $1.rowHeight + spacing })
                x = 0
            }
            current.items.append(.init(index: index, x: x, width: size.width))
            current.rowHeight = max(current.rowHeight, size.height)
            x += size.width + spacing
        }
        if !current.items.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

private struct Row {
    struct Item {
        let index: Int
        let x: CGFloat
        let width: CGFloat
    }
    
    var items: [Item] = []
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
}
