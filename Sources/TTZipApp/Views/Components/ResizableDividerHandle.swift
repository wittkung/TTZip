import SwiftUI

/// 侧边栏及分栏可拖拽 Handle 控件
public struct ResizableDividerHandle: View {
    public var onDragStart: (() -> Void)? = nil
    public let onDragChanged: (CGFloat) -> Void
    public var onDragEnd: (() -> Void)? = nil
    
    @State private var isHovered = false
    @State private var isDragging = false
    @State private var startMouseX: CGFloat = 0
    
    public init(onDragStart: (() -> Void)? = nil, onDragChanged: @escaping (CGFloat) -> Void, onDragEnd: (() -> Void)? = nil) {
        self.onDragStart = onDragStart
        self.onDragChanged = onDragChanged
        self.onDragEnd = onDragEnd
    }
    
    public var body: some View {
        ZStack {
            Rectangle()
                .fill(isHovered || isDragging ? TTZipTheme.bambooGreen.opacity(0.8) : Color.clear)
                .frame(width: (isHovered || isDragging) ? 3 : 1)
        }
        .frame(width: 14)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { _ in
                    let currentMouseX = NSEvent.mouseLocation.x
                    if !isDragging {
                        isDragging = true
                        startMouseX = currentMouseX
                        onDragStart?()
                    }
                    let deltaX = currentMouseX - startMouseX
                    onDragChanged(deltaX)
                }
                .onEnded { _ in
                    isDragging = false
                    onDragEnd?()
                }
        )
    }
}

public struct ResizableHorizontalDividerHandle: View {
    @Binding public var height: CGFloat
    public var minHeight: CGFloat = 100
    public var maxHeight: CGFloat = 500
    @State private var isHovered = false
    
    public init(height: Binding<CGFloat>, minHeight: CGFloat = 100, maxHeight: CGFloat = 500) {
        self._height = height
        self.minHeight = minHeight
        self.maxHeight = maxHeight
    }
    
    public var body: some View {
        ZStack {
            Rectangle()
                .fill(isHovered ? TTZipTheme.bambooGreen.opacity(0.8) : Color.primary.opacity(0.08))
                .frame(height: isHovered ? 2 : 1)
        }
        .frame(height: 8)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.resizeUpDown.push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let newHeight = height + value.translation.height
                    height = min(max(newHeight, minHeight), maxHeight)
                }
        )
    }
}

public struct SidebarToggleButton: View {
    @Binding public var isSidebarVisible: Bool
    @State private var isHovered = false
    
    public init(isSidebarVisible: Binding<Bool>) {
        self._isSidebarVisible = isSidebarVisible
    }
    
    public var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isSidebarVisible.toggle()
            }
            isHovered = false
        }) {
            ZStack {
                Circle()
                    .fill(Color.primary.opacity(isHovered ? 0.05 : 0))
                    .frame(width: 32, height: 32)
                
                Image(systemName: isSidebarVisible ? "chevron.left" : "chevron.right")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundStyle(isHovered ? Color.primary : Color.secondary)
                    .offset(x: isSidebarVisible ? -1 : 1)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}
